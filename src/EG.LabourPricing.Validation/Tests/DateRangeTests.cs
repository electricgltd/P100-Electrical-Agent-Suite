using System;
using Xunit;
using FluentAssertions;
using EG.LabourPricing.Validation.Helpers;

namespace EG.LabourPricing.Validation.Tests
{
    public class DateRangeTests
    {
        [Theory]
        [InlineData("2025-01-01", "2025-06-30", "2025-07-01", "2025-12-31", false)] // Touching - OK
        [InlineData("2025-01-01", "2025-06-30", "2025-06-30", "2025-12-31", true)]  // Same day overlap - NOT OK
        [InlineData("2025-01-01", "2025-06-30", "2025-06-15", "2025-12-31", true)]  // Inside overlap - NOT OK
        [InlineData("2025-01-01", "2025-06-30", "2024-06-01", "2025-01-15", true)]  // Surrounding overlap - NOT OK
        [InlineData("2025-01-01", "2025-06-30", "2025-01-01", "2025-06-30", true)]  // Duplicate range - NOT OK
        [InlineData("2025-01-01", null, "2025-06-01", "2025-12-31", true)]          // New open-ended overlaps existing - NOT OK
        [InlineData("2025-01-01", "2025-06-30", "2025-07-01", null, false)]         // Existing open-ended, new ends before - OK
        [InlineData("2025-01-01", null, "2025-06-01", null, true)]                  // Both open-ended - NOT OK
        [InlineData("2025-01-01", null, "2026-01-01", null, true)]                  // Both open-ended, later start - NOT OK
        public void Overlaps_ShouldDetectOverlapsCorrectly(string newStartStr, string? newEndStr, string existingStartStr, string? existingEndStr, bool expectedOverlap)
        {
            // Arrange
            var newStart = DateTime.Parse(newStartStr);
            var newEnd = newEndStr != null ? DateTime.Parse(newEndStr) : (DateTime?)null;
            var existingStart = DateTime.Parse(existingStartStr);
            var existingEnd = existingEndStr != null ? DateTime.Parse(existingEndStr) : (DateTime?)null;

            // Act
            var result = DateRange.Overlaps(newStart, newEnd, existingStart, existingEnd);

            // Assert
            result.Should().Be(expectedOverlap, 
                $"Range {DateRange.FormatDateRange(newStart, newEnd)} and {DateRange.FormatDateRange(existingStart, existingEnd)} should {(expectedOverlap ? "" : "not ")}overlap");
        }

        [Fact]
        public void Overlaps_WithNullStartDates_ShouldReturnFalse()
        {
            // Arrange & Act & Assert
            DateRange.Overlaps(null, DateTime.Today, DateTime.Today, DateTime.Today).Should().BeFalse();
            DateRange.Overlaps(DateTime.Today, DateTime.Today, null, DateTime.Today).Should().BeFalse();
            DateRange.Overlaps(null, null, null, null).Should().BeFalse();
        }

        [Fact]
        public void Overlaps_BoundaryCase_ExactNextDay_ShouldNotOverlap()
        {
            // Arrange
            var range1End = new DateTime(2025, 6, 30);
            var range2Start = new DateTime(2025, 7, 1); // Next day

            // Act
            var result = DateRange.Overlaps(
                new DateTime(2025, 1, 1), range1End,
                range2Start, new DateTime(2025, 12, 31));

            // Assert
            result.Should().BeFalse("Ranges that touch at boundaries should not overlap");
        }

        [Fact]
        public void Overlaps_BoundaryCase_SameDay_ShouldOverlap()
        {
            // Arrange
            var sharedDate = new DateTime(2025, 6, 30);

            // Act
            var result = DateRange.Overlaps(
                new DateTime(2025, 1, 1), sharedDate,
                sharedDate, new DateTime(2025, 12, 31));

            // Assert
            result.Should().BeTrue("Ranges that share the same end/start date should overlap");
        }

        [Theory]
        [InlineData("2025-01-01", "2025-06-30", "[2025-01-01 .. 2025-06-30]")]
        [InlineData("2025-01-01", null, "[2025-01-01 .. null]")]
        public void FormatDateRange_ShouldFormatCorrectly(string startStr, string? endStr, string expected)
        {
            // Arrange
            var start = DateTime.Parse(startStr);
            var end = endStr != null ? DateTime.Parse(endStr) : (DateTime?)null;

            // Act
            var result = DateRange.FormatDateRange(start, end);

            // Assert
            result.Should().Be(expected);
        }

        [Fact]
        public void FormatDateRange_WithNullStart_ShouldReturnInvalidRange()
        {
            // Act
            var result = DateRange.FormatDateRange(null, DateTime.Today);

            // Assert
            result.Should().Be("Invalid range");
        }

        [Fact]
        public void Overlaps_RealWorldScenario_ConsecutiveRanges_ShouldNotOverlap()
        {
            // Arrange - Policy "Default 2025", Role "Main Electrician"
            var range1Start = new DateTime(2025, 1, 1);
            var range1End = new DateTime(2025, 6, 30);
            var range2Start = new DateTime(2025, 7, 1);
            DateTime? range2End = null; // Open-ended

            // Act
            var result = DateRange.Overlaps(range1Start, range1End, range2Start, range2End);

            // Assert
            result.Should().BeFalse("Consecutive ranges should not overlap when properly configured");
        }

        [Fact]
        public void Overlaps_RealWorldScenario_AccidentalOverlap_ShouldDetect()
        {
            // Arrange - Accidentally creating overlapping period
            var existingStart = new DateTime(2025, 1, 1);
            var existingEnd = new DateTime(2025, 6, 30);
            var newStart = new DateTime(2025, 6, 1); // Starts before existing ends
            var newEnd = new DateTime(2025, 12, 31);

            // Act
            var result = DateRange.Overlaps(newStart, newEnd, existingStart, existingEnd);

            // Assert
            result.Should().BeTrue("Overlapping ranges should be detected to prevent data integrity issues");
        }
    }
}