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

## @desc Actions/transforms for general string processing.

# HACK (Daniel): Can't use backreferences with non_catching_regex.
QuotedValueRegexp = /(?:the )?(?:value |phrase |text )?(?:"((?:[^"]|(?<=\\)")*)"|'((?:[^']|(?<=\\)')*)')/
#QuotedValueRegexp = /(?:the )?(?:value |phrase |text )?(?:"((?:[^"\\]|\\"|\\n|\\\\)*)")|(?:'((?:[^'\\]|\\'|\\n|\\\\)*)')/
QuotedValue = LaserTransform QuotedValueRegexp do |value1, value2|
	## @name QuotedValue
	## @format [the ][(value|phrase|text)] "|value|"
	## @desc Represents an arbitrary string, |value|. Use the escape character back-slash (\) for quotes and back-slashes, e.g. the value "He said, \"Hello.\""; text "the file C:\\AUTOEXEC.BAT".
	quote = value1 ? '"' : "'"
	value = value1 || value2
	value.gsub("\\\\", "\\").gsub("\\#{quote}", "#{quote}").gsub("\\n", "\n").force_encoding('utf-8')
end

QuotedValueRegexpPure = /"((?:[^"]|(?<=\\)")*)"|'((?:[^']|(?<=\\)')*)'/

QuotedValuePure = LaserTransform QuotedValueRegexpPure do |value1, value2|
  ## @name QuotedValue
  ## @format [the ][(value|phrase|text)] "|value|"
  ## @desc Represents an arbitrary string, |value|. Use the escape character back-slash (\) for quotes and back-slashes, e.g. the value "He said, \"Hello.\""; text "the file C:\\AUTOEXEC.BAT".
  quote = value1 ? '"' : "'"
  value = value1 || value2
  value.gsub("\\\\", "\\").gsub("\\#{quote}", "#{quote}").gsub("\\n", "\n").force_encoding('utf-8')
end
