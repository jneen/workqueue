require 'thread'

class WorkQueue
  class ThreadsafeAggregator < Array
    def mutex
      @mutex ||= Mutex.new
    end

    def push(o)
      mutex.synchronize { super(o) }
    end
    alias << push
  end

  attr_reader :queue
  attr_reader :job
  def initialize(&job)
    @job = job
    @queue = Queue.new
  end

  def aggregator
    @aggregator ||= ThreadsafeAggregator.new
  end

  def workers
    @workers ||= (1..10).map do
      Thread.new do
        until @aborted or (@joined and queue.empty?)
          begin
            aggregator << job.call(queue.shift)
          rescue Exception
            @aborted = true
            raise
          end
        end
      end
    end
  end

  def run
    workers.map(&:start)
  end

  def push(e)
    @queue.push(e)
  end
  alias << push

  def join
    @joined = true
    workers.each(&:join)
  end

  def results
    join
    aggregator.to_a
  end
end
