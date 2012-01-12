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

## @desc Actions involving waiting for things, error messages and block messages on timeouts, etc.

When /^I (?:wait|sleep|pause) (?:for )?(#{TimeLength})(?: \([Rr]eason:(?:.*)\))?$/ do |time|
	## @desc Pauses test execution for |time|.
	sleep time
end

def works_within time, check, &f
	puts "[works_within] Started with: #{time} checking every #{check}"
	start = Time.now
	check ||= 1
	nextt = start + check
	puts "[works_within] Start Time: #{start}"

	loop do
		begin
			f.call
			puts "[works_within] Finishing successfully"
			break
		rescue Exception => e
			raise e if e.is_a? Cucumber::Undefined or e.is_a? Cucumber::Pending or e.is_a? Cucumber::Ambiguous

			now = Time.now
			puts "[works_within] Now: #{now}"
			elapsed = now - start
			puts "[works_within] Elapsed: #{elapsed} (out of #{time})"
			raise e if elapsed > time

			nextt += check while nextt < now
			puts "[works_within] Going to sleep for #{nextt - now}"
			sleep nextt - now
		end
	end
end

WrapTransform /within (#{TimeLength})(?: checking every (#{TimeLength}))?/ do |step, time, check|
	works_within(time, check) do
		When step
	end
end
