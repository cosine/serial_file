
RSpec::Matchers.define :stoppy do |secs|
  match do |target|
    thread = Thread.new { target.call }
    break false if thread.join(secs)
    # A thread is blocked if alive and stopped.
    return_value = thread.alive? && thread.stop?
    thread.kill
    return_value
  end
end
require 'ruby-debug'; debugger
a=1
def stoppy (secs)
  RSpec::Matchers::Stoppy.new(secs)
end

=begin
class RspecBlock
  def matches? (target)
    thread = Thread.new { target.call }
    return false if thread.join(2)
    # A thread is blocked if alive and stopped.
    if thread.alive? && thread.stop?
      thread.kill
      true
    else
      false
    end
  end

  def failure_message_for_should
    "expected blocking but proc completed"
  end

  def failure_message_for_should_not
    "expected no blocking but proc was blocked"
  end
end


def block
  RspecBlock.new
end
=end
