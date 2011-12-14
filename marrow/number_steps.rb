# Copyright 2010-2011 Noble Samurai
# 
# Marrow is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Marrow is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Marrow.  If not, see <http://www.gnu.org/licenses/>.

## @desc Provides support transforms for handling numbers.

# Note below that we put the ^ and $ for the Transform in at the Transform
# stage, otherwise the non-catching versions would have them too, and they'd
# match nothing in any context at all.

# Ordinalities - ordering numbers
#

Ordinalities = %w(first second third fourth fifth sixth seventh eighth) +
  %w(ninth tenth eleventh twelfth thirteenth fourteenth fifteenth sixteenth) +
  %w(seventeenth eighteenth nineteenth twentieth)

OrdinalityRegexp = /(every|any|the\ (first|second|third|fourth|fifth|sixth|seventh|eighth|
                    ninth|tenth|evelenth|twelfth|thirteenth|fourteenth|fifteenth|sixteenth|
                    seventeenth|eighteenth|nineteenth|twentieth|last|[1-9][0-9]*(?:th|nd|rd|st)))/xi
Ordinality = LaserTransform OrdinalityRegexp do |type, ordinality|
	## @name Ordinality
	## @format (every|any|the (first|second|third|fourth|fifth|...|last|1st|2nd|3rd|4th|5th|...))
	## @desc Represents an ordinality - denoting position in a sequence. English words are supported up to "twentieth" - otherwise use the numeric form (unlimited). Note that a zero index <strong>is not</strong> possible - arrays of objects start at 'first', not 'zeroth'. You can request the last (-1th) if the object supports it.
	next type if type == 'every' or type == 'any'
	next -1 if type == 'last'
	next Ordinalities.index(ordinality.downcase) if Ordinalities.include?(ordinality.downcase)
	ordinality.to_i - 1
end

# Cardinalities - counting numbers.
#

Cardinalities = %w(zero one two three four five six seven eight nine ten) +
  %w(eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty)
CardinalityRegexp = /(a(?:n)?|zero|one|two|three|four|five|six|seven|eight|nine|ten|
                     eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|
                     [0-9]+)/xi
Cardinality = LaserTransform CardinalityRegexp do |cardinality|
  ## @name Cardinality
  ## @format (zero|a[n]|one|two|three|four|...|0|1|2|3|4|...)
  ## @desc Represents a cardinality - denoting a count of objects. English words are supported up to "twenty" and "a"/"an" - otherwise use the numeric form (unlimited). Note that a zero count <strong>is</strong> possible.
  next 1 if cardinality.downcase == "a" || cardinality.downcase == "an"
  next Cardinalities.index(cardinality.downcase) if Cardinalities.include?(cardinality.downcase)
  cardinality.to_i
end

# Lengths of time - turns a string representing a time period into the number of seconds
#

TimeLengthRegexp = /(#{Cardinality})\ ?(s(?:econd)?|m(?:inute)?|h(?:our)?|d(?:ay)?|w(?:eek)?|month|year|decade)(?:s)?/xi
TimeLength = LaserTransform TimeLengthRegexp do |num, type|
	## @name TimeLength
	## @format <<Cardinality>>[ ](s[econd]|m[inute]|h[our]|d[ay]|w[eek]|month|year|decade)[s]
	## @desc Represents a length of time - currently supporting the above-mentioned timespans. Support for centuries, millenia, etc. was not included, as you cannot neatly add an 's' to get the plural form. Please note that the month, year and decade are all an average month, year and decade, correcting for leap years, but not leap seconds.
	mult = case type
	       when /^decade$/i; 315576000
	       when /^year$/i;   31557600
	       when /^month$/i;  2629800
	       when /^week$/i;   604800
	       when /^day$/i;    86400
	       when /^hour$/i;   3600
	       when /^min/i;     60
	       else;             1
	       end
	mult * num
end
