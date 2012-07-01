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

require 'cucumber'
require 'cucumber/rb_support/rb_transform'
require 'digest/md5'

def non_catching_regex(r)
	# Turns /(abc)/ into /(?:abc)/, being careful not to ruin other complex
	# expressions.
	# Does not double-up groups with "?:" already specified.
	# Preserves options such as in (?i-mx:abc).
	transformed = source.gsub(/
		# Match "(", as long as it's not immediately following a "\".
		(?<! \\ ) \(

		# Fail if "?#", "?<", "?!" or "?=" follows.
		(?! \?\# | \?< | \?! | \?= )

		# Optionally match options, which look like:
		#   "?mix:"
		#   "?i-mx:"
		#   etc.
		# Capture just the "i-mx" part.
		(?: \?([\-mix]*): )?
	/x) {
		# Return "(?:" with any options inserted between.
		"(?#$1:"
	}
	Regexp.new(transformed, options)
end

# Hacky excuse for a parser. I'm tired.
def capture_groups(r)  	
	#p "Finding capture groups for: #{r.source}"
	chars = r.source.chars.to_a
	opens = []
	ignore = []
	groups = {}

	escape = false

	chars.each_with_index do |ch, i|
		if escape
			escape = false
			next
		end

		case ch
		when '\\'
			escape = true
		when '('
			opens << (i < chars.length-1 && chars[i+1] == '?' ? -1 : i)
		when ')'
			j = opens.pop
			if j != -1
				groups[j] = chars[j..i].join
			end
		end
	end

	#puts groups.reverse.inspect + "\n\n"
	groups.keys.sort.map {|open| groups[open]}
end

class String
	def hyphenate
		gsub(' ', '-').downcase
	end

	def dehyphenate
		gsub('-', ' ')
	end

	def underscore
		gsub(' ', '_').downcase
	end
end

class CandidateNotFoundError < StandardError; end

Cucumber::Ast::StepInvocation.class_variable_set "@@before_steps", []
Cucumber::Ast::Feature.class_variable_set "@@before_features", []

def BeforeStep &block
	before_steps = Cucumber::Ast::StepInvocation.class_variable_get "@@before_steps"
	before_steps << block
	Cucumber::Ast::StepInvocation.class_variable_set "@@before_steps", before_steps
end

def BeforeFeature &block
	before_features = Cucumber::Ast::Feature.class_variable_get "@@before_features"
	before_features << block
	Cucumber::Ast::Feature.class_variable_set "@@before_features", before_features
end

def WarpTransform(rxp, &block)
	When /^(.*?)#{rxp}(.*?)$/	do |*args|
		before = args[0]
		after = args[-1]

		steps "When #{before}#{block.call(*args[1..-2])}#{after}"
	end
end

def WrapTransform(rxp, &block)
	When /^(.*?) #{rxp}$/ do |step, *args|
		instance_exec(step, *args, &block)
	end
end

module Cucumber
	module Ast
		class TreeWalker
			attr_accessor :listeners
		end

		# Before Feature
		class Feature
			alias _real_honest_init init
			def init
				@@before_features.each do |b|
					 instance_eval &b
				end
				_real_honest_init
			end
		end

		# Before Step
		class StepInvocation
			alias _real_honest_invoke invoke
			def invoke *opts, &b
				@@before_steps.each do |b|
					instance_eval &b
				end
				_real_honest_invoke *opts, &b
			end
		end
	end

	module RbSupport
		class RbTransform
			# Call the real match.  Then try invoking the method,
			# just to see  if we get a CandidateNotFoundError.
			# Don't try this, however, if we were called from our
			# own custom invoke.
			old_match = instance_method(:match)
			define_method :match do |arg|
				result = old_match.bind(self).call(arg)

				if result and not @invoking
					begin
						self.invoke(arg)
					rescue CandidateNotFoundError
						result = nil
					end
				end
				result
			end

			# Just call the real invoke, while setting the
			# invoking status to true.  This prevents loops in
			# match so it doesn't attempt to multiply invoke
			# itself.
			old_invoke = instance_method(:invoke)
			define_method :invoke do |arg|
				@invoking = true
				begin
					old_invoke.bind(self).call(arg)
				ensure
					@invoking = false
				end
			end
		end

		## The following primarily consists of hacking/rewriting parts of Cucumber to make LaserTransform work.

		class RbLaserTransform < RbTransform
			def initialize(rb_language, pattern, proc, identifier)
				super(rb_language, pattern, proc);
				@identifier = identifier;
			end

			def match(arg, capgroup)
				#puts "Matching\n" + 
				#		  "  `#{capgroup}`\n" +
				#		  "  `#{arg}`\n" +
				#		  "against\n" +
				#		  "  `#{@identifier}`\n" +
				#		  "  `#{@regexp}`\n"
				if arg && capgroup && capgroup.include?(@identifier)
					arg.match(@regexp)
				else
					nil
				end
			end

			def Transform(arg, *contexts)
				if contexts.length > 0
					context = /#{contexts.map {|ctxt| ctxt.is_a?(Regexp) ? ctxt.source : ctxt}.join}/
				else
					context = nil
				end

				@rb_language.execute_transforms([arg], context, false).first
			end

			def invoke(arg, capgroup)
				if matched = match(arg, capgroup)
					if matched.captures.empty?
						[arg]
					else
						newargs = matched.captures

						# For nested LaserTransforms
						capgroups = capture_groups(@regexp)
						0.upto(newargs.length-1) do |i|
							newargs[i] = Transform(newargs[i], capgroups[i])
						end

						@rb_language.current_world.cucumber_instance_exec(true, @regexp.inspect, *newargs, &@proc)
					end
				end
			end
		end

		class RbStepDefinition
			def invoke(args)
			args = args.map{|arg| Ast::PyString === arg ? arg.to_s : arg}
				begin
					args = @rb_language.execute_transforms(args, @regexp)
					@rb_language.current_world.cucumber_instance_exec(true, regexp_source, *args, &@proc)
				rescue Cucumber::ArityMismatchError => e
					e.backtrace.unshift(self.backtrace_line)
					raise e
				end
			end
		end

		class RbLanguage
			def register_rb_laser_transform(regexp, proc, identifier)
				add_transform(RbLaserTransform.new(self, regexp, proc, identifier))
			end
		end

		module RbDsl
			class << self
				def register_rb_laser_transform(regexp, proc, identifier)
					@rb_language.register_rb_laser_transform(regexp, proc, identifier)
				end
			end

			def LaserTransform(regexp, &proc)
				identifier = Digest::MD5.hexdigest(regexp.source)
				modexp = Regexp.new("(?##{identifier})" + regexp.source, regexp.options)
				RbDsl.register_rb_laser_transform(/^#{modexp}$/, proc, identifier)
				return non_catching_regex(modexp);
			end
		end

		module RbWorld
			# Call a Transform with a string from another Transform definition
			def Transform(arg, *contexts)
				return arg unless arg.is_a? String

				if contexts.length > 0
					context = /#{contexts.map {|ctxt| ctxt.is_a?(Regexp) ? ctxt.source : ctxt}.join}/
				else
					context = nil
				end

				rb = @__cucumber_step_mother.load_programming_language('rb')
				rb.execute_transforms([arg], context, false).first
			end
		end
	end

	module LanguageSupport
		module LanguageMethods
			def execute_transforms(args, stepexp=nil, grouplaser=true)
				if stepexp
					captures = (grouplaser ? capture_groups(stepexp) : [stepexp.source]*args.length)
				end
  
				args.map do |arg|
					matching_transform = transforms.detect do |transform| 
						(stepexp && transform.is_a?(RbSupport::RbLaserTransform)) ? transform.match(arg, captures[args.index(arg)]) : transform.match(arg) 
					end

					if matching_transform
						if stepexp and matching_transform.is_a? RbSupport::RbLaserTransform
							matching_transform.invoke(arg, captures[args.index(arg)])
						else
							matching_transform.invoke(arg)
						end
					else
						arg
					end
				end
			end
		end
	end
end
