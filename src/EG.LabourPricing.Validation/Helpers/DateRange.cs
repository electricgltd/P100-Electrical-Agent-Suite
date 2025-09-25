using System;

namespace EG.LabourPricing.Validation.Helpers
{
    /// <summary>
    /// Helper class for date range overlap detection logic
    /// </summary>
    public static class DateRange
    {
        /// <summary>
        /// Determines if two date ranges overlap, treating null end dates as infinite.
        /// Business rule: Touching dates are OK (prev.EndDate < next.StartDate), same-day overlap is NOT OK.
        /// </summary>
        /// <param name="newStart">Start date of new range</param>
        /// <param name="newEnd">End date of new range (null = infinite)</param>
        /// <param name="existingStart">Start date of existing range</param>
        /// <param name="existingEnd">End date of existing range (null = infinite)</param>
        /// <returns>True if ranges overlap, false if they don't overlap or only touch at boundaries</returns>
        public static bool Overlaps(DateTime? newStart, DateTime? newEnd, DateTime? existingStart, DateTime? existingEnd)
        {
            if (!newStart.HasValue || !existingStart.HasValue)
                return false; // Can't determine overlap without start dates

            var newStartDate = newStart.Value.Date;
            var existingStartDate = existingStart.Value.Date;
            
            // Convert null end dates to max value to represent infinite
            var newEndDate = newEnd?.Date ?? DateTime.MaxValue.Date;
            var existingEndDate = existingEnd?.Date ?? DateTime.MaxValue.Date;

            // Ranges overlap if:
            // !(newEnd < existingStart OR newStart > existingEnd)
            // Which simplifies to: newEnd >= existingStart AND newStart <= existingEnd
            return newEndDate >= existingStartDate && newStartDate <= existingEndDate;
        }

        /// <summary>
        /// Formats a date range for display in error messages
        /// </summary>
        /// <param name="startDate">Start date</param>
        /// <param name="endDate">End date (null = infinite)</param>
        /// <returns>Formatted date range string</returns>
        public static string FormatDateRange(DateTime? startDate, DateTime? endDate)
        {
            if (!startDate.HasValue)
                return "Invalid range";

            var start = startDate.Value.ToString("yyyy-MM-dd");
            var end = endDate?.ToString("yyyy-MM-dd") ?? "null";
            
            return $"[{start} .. {end}]";
        }
    }
}