# Copyright 2010 Noble Samurai
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

## @desc Actions involving waiting for things, error messages and block messages on timeouts, etc.

When /^I (?:wait|sleep|pause) (?:for )?(#{TimeLength})(?: \([Rr]eason:(?:.*)\))?$/ do |time|
  ## @desc Pauses test execution for |time|.
  sleep time
end

WrapTransform /within (#{TimeLength})(?: checking every (#{TimeLength}))?/ do |step, time, check|
  count = 0

	check ||= 1

  loop do

    begin
      When step
      break
    rescue Exception => e
      raise e if e.is_a? Cucumber::Undefined or e.is_a? Cucumber::Pending or e.is_a? Cucumber::Ambiguous

      if count > time
        raise e
      else
        count += check
        sleep check
      end
    end

  end
end
