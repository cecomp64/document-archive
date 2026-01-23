module DocumentArchive
  class PublicationDateParser
    # Month abbreviations mapping
    MONTH_ABBREVS = {
      "jan" => 1, "feb" => 2, "mar" => 3, "apr" => 4,
      "may" => 5, "jun" => 6, "jul" => 7, "aug" => 8,
      "sep" => 9, "oct" => 10, "nov" => 11, "dec" => 12
    }.freeze

    # Parse a document name and extract a publication date
    # Examples:
    #   "SJAA1961"     => 1961-01-01
    #   "SJAA1964"     => 1964-01-01
    #   "Eph79_06"     => 1979-06-01
    #   "Eph79_07"     => 1979-07-01
    #   "Eph79_05Un"   => 1979-05-01
    #   "eph78_Misc"   => 1978-01-01
    #   "Misc_80"      => 1980-01-01
    def self.parse(name)
      return nil if name.blank?

      # Try different patterns
      date = try_four_digit_year_with_month(name) ||
             try_two_digit_year_with_month(name) ||
             try_four_digit_year_only(name) ||
             try_two_digit_year_only(name)

      date
    end

    class << self
      private

      # Pattern: 4-digit year followed by underscore and 2-digit month
      # e.g., "Doc2019_03" => 2019-03-01
      def try_four_digit_year_with_month(name)
        if name =~ /(\d{4})[_-](\d{2})/
          year = ::Regexp.last_match(1).to_i
          month = ::Regexp.last_match(2).to_i
          return build_date(year, month)
        end

        # 4-digit year followed by month abbreviation
        if name =~ /(\d{4})[_-]?([a-z]{3})/i
          year = ::Regexp.last_match(1).to_i
          month = MONTH_ABBREVS[::Regexp.last_match(2).downcase]
          return build_date(year, month) if month
        end

        nil
      end

      # Pattern: prefix + 2-digit year + underscore + 2-digit month
      # e.g., "Eph79_06" => 1979-06-01
      def try_two_digit_year_with_month(name)
        # Look for pattern like "Eph79_06" or "eph78_05Un"
        if name =~ /([a-z]+)(\d{2})[_-](\d{2})/i
          year = expand_two_digit_year(::Regexp.last_match(2).to_i)
          month = ::Regexp.last_match(3).to_i
          return build_date(year, month)
        end

        # Look for month abbreviation followed by 2-digit year (e.g., "EphSep99")
        if name =~ /([a-z]{3})(\d{2})(?:[^0-9]|$)/i
          month = MONTH_ABBREVS[::Regexp.last_match(1).downcase]
          if month
            year = expand_two_digit_year(::Regexp.last_match(2).to_i)
            return build_date(year, month)
          end
        end

        # Look for 2-digit year followed by month abbreviation
        if name =~ /(\d{2})[_-]?([a-z]{3})/i
          year = expand_two_digit_year(::Regexp.last_match(1).to_i)
          month = MONTH_ABBREVS[::Regexp.last_match(2).downcase]
          return build_date(year, month) if month
        end

        nil
      end

      # Pattern: 4-digit year only
      # e.g., "SJAA1961" => 1961-01-01
      def try_four_digit_year_only(name)
        if name =~ /(\d{4})/
          year = ::Regexp.last_match(1).to_i
          return build_date(year, 1) if year >= 1900 && year <= 2100
        end
        nil
      end

      # Pattern: 2-digit year only (with prefix or suffix)
      # e.g., "Misc_80" => 1980-01-01, "eph78_Misc" => 1978-01-01
      def try_two_digit_year_only(name)
        # Prefix + 2-digit year pattern (e.g., "eph78")
        if name =~ /([a-z]+)(\d{2})(?:[_-]|$)/i
          year = expand_two_digit_year(::Regexp.last_match(2).to_i)
          return build_date(year, 1)
        end

        # Suffix pattern with underscore (e.g., "Misc_80")
        if name =~ /[_-](\d{2})(?:[_-]|$)/
          year = expand_two_digit_year(::Regexp.last_match(1).to_i)
          return build_date(year, 1)
        end

        nil
      end

      def expand_two_digit_year(two_digit)
        # Assume years 00-30 are 2000s, 31-99 are 1900s
        if two_digit <= 30
          2000 + two_digit
        else
          1900 + two_digit
        end
      end

      def build_date(year, month)
        return nil unless year && year >= 1900 && year <= 2100
        return nil unless month && month >= 1 && month <= 12

        Date.new(year, month, 1)
      rescue ArgumentError
        nil
      end
    end
  end
end
