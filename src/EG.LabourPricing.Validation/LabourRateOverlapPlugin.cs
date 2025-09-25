using System;
using System.Linq;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using EG.LabourPricing.Validation.Helpers;

namespace EG.LabourPricing.Validation
{
    /// <summary>
    /// Plugin to validate that Labour Rate effective date ranges do not overlap
    /// for the same (PolicyId, RoleId) combination.
    /// 
    /// Registers on: Create and Update of beren_LabourRatesEffective
    /// Stage: Post-operation, Synchronous
    /// </summary>
    public class LabourRateOverlapPlugin : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            // Get the execution context
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var serviceFactory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            var service = serviceFactory.CreateOrganizationService(context.UserId);
            var tracingService = (ITracingService)serviceProvider.GetService(typeof(ITracingService));

            try
            {
                tracingService.Trace($"LabourRateOverlapPlugin: Starting execution for message '{context.MessageName}'");

                // Only process Create and Update messages
                if (context.MessageName != "Create" && context.MessageName != "Update")
                {
                    tracingService.Trace("Plugin not relevant for this message type");
                    return;
                }

                // Get the target entity
                if (!(context.InputParameters["Target"] is Entity targetEntity))
                {
                    tracingService.Trace("No target entity found");
                    return;
                }

                // Validate this is the correct entity
                if (targetEntity.LogicalName != "beren_labourrateseffective")
                {
                    tracingService.Trace($"Plugin not relevant for entity '{targetEntity.LogicalName}'");
                    return;
                }

                ValidateLabourRateOverlap(service, tracingService, context, targetEntity);
            }
            catch (Exception ex)
            {
                tracingService.Trace($"Error in LabourRateOverlapPlugin: {ex}");
                throw new InvalidPluginExecutionException($"Error validating Labour Rate overlap: {ex.Message}", ex);
            }
        }

        private void ValidateLabourRateOverlap(IOrganizationService service, ITracingService tracingService, IPluginExecutionContext context, Entity targetEntity)
        {
            // Extract required fields from target entity
            var policyId = GetEntityReference(targetEntity, "beren_pricingpolicy");
            var roleId = GetEntityReference(targetEntity, "beren_labourrole");
            var startDate = GetDateTime(targetEntity, "beren_validfrom");
            var endDate = GetDateTime(targetEntity, "beren_validto"); // Nullable

            tracingService.Trace($"Processing Labour Rate: Policy={policyId?.Id}, Role={roleId?.Id}, Range={DateRange.FormatDateRange(startDate, endDate)}");

            // Skip validation if we don't have required fields
            if (policyId == null || roleId == null || !startDate.HasValue)
            {
                tracingService.Trace("Missing required fields for overlap validation");
                return;
            }

            // Query for existing Labour Rate records for the same (PolicyId, RoleId)
            var existingRates = GetExistingLabourRates(service, tracingService, policyId.Id, roleId.Id, targetEntity.Id, context.MessageName == "Update");

            // Check for overlaps with existing records
            foreach (var existingRate in existingRates.Entities)
            {
                var existingStart = GetDateTime(existingRate, "beren_validfrom");
                var existingEnd = GetDateTime(existingRate, "beren_validto");

                if (DateRange.Overlaps(startDate, endDate, existingStart, existingEnd))
                {
                    var policyName = GetPolicyName(service, policyId.Id);
                    var roleName = GetRoleName(service, roleId.Id);
                    
                    var errorMessage = $"OVERLAP: Existing {DateRange.FormatDateRange(existingStart, existingEnd)} for Role={roleName}, Policy={policyName}";
                    
                    tracingService.Trace($"Overlap detected: {errorMessage}");
                    throw new InvalidPluginExecutionException(errorMessage);
                }
            }

            tracingService.Trace("No overlaps detected - validation passed");
        }

        private EntityCollection GetExistingLabourRates(IOrganizationService service, ITracingService tracingService, Guid policyId, Guid roleId, Guid currentRecordId, bool isUpdate)
        {
            var query = new QueryExpression("beren_labourrateseffective")
            {
                ColumnSet = new ColumnSet("beren_labourrateseffectiveid", "beren_validfrom", "beren_validto"),
                Criteria = new FilterExpression(LogicalOperator.And)
            };

            // Filter by same PolicyId and RoleId
            query.Criteria.AddCondition("beren_pricingpolicy", ConditionOperator.Equal, policyId);
            query.Criteria.AddCondition("beren_labourrole", ConditionOperator.Equal, roleId);

            // Exclude current record if this is an update
            if (isUpdate)
            {
                query.Criteria.AddCondition("beren_labourrateseffectiveid", ConditionOperator.NotEqual, currentRecordId);
            }

            tracingService.Trace($"Querying existing Labour Rates for Policy={policyId}, Role={roleId}");
            
            var result = service.RetrieveMultiple(query);
            tracingService.Trace($"Found {result.Entities.Count} existing Labour Rate records");
            
            return result;
        }

        private string GetPolicyName(IOrganizationService service, Guid policyId)
        {
            try
            {
                var policy = service.Retrieve("beren_pricingpolicy", policyId, new ColumnSet("beren_pricingpolicyname"));
                return policy.GetAttributeValue<string>("beren_pricingpolicyname") ?? "Unknown Policy";
            }
            catch
            {
                return $"Policy({policyId})";
            }
        }

        private string GetRoleName(IOrganizationService service, Guid roleId)
        {
            try
            {
                var role = service.Retrieve("beren_labourratesagent", roleId, new ColumnSet("beren_name"));
                return role.GetAttributeValue<string>("beren_name") ?? "Unknown Role";
            }
            catch
            {
                return $"Role({roleId})";
            }
        }

        private EntityReference GetEntityReference(Entity entity, string attributeName)
        {
            return entity.Contains(attributeName) ? entity.GetAttributeValue<EntityReference>(attributeName) : null;
        }

        private DateTime? GetDateTime(Entity entity, string attributeName)
        {
            return entity.Contains(attributeName) ? entity.GetAttributeValue<DateTime?>(attributeName) : null;
        }
    }
}