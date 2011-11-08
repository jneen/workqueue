require 'thread'

class WorkQueue
  class ThreadsafeCounter
    def initialize(count=0)
      @count = count
    end

    def incr(by=1)
      mutex.synchronize { @count += by }
    end

  private
    def mutex
      @mutex ||= Mutex.new
    end
  end

  attr_reader :queue
  attr_reader :job
  def initialize(init_queue=[], opts={}, &job)
    @job = job
    @queue = Queue.new

    opts.each { |k, v| send(:"#{k}=", v) }

    concat(init_queue)
  end

  attr_writer :size
  def size
    @size ||= 2
  end

  def workers
    @workers ||= []
  end

  def work!
    until @aborted or (@joined and queue.empty?)
      begin
        payload, index = queue.shift
        aggregate[index] = job.call(payload)
      rescue Exception
        @aborted = true
        raise
      end
    end
  end

  def run
    @workers ||= (1..size).map do
      Thread.new { work! }
    end

    self
  end

  def push(e)
    @queue.push([e, cursor.incr])

    self
  end
  alias << push

  def concat(arr)
    arr.each { |x| push(x) }
  end

  def join
    @joined = true
    workers.each(&:join)

    self
  end

  def results
    join
    aggregate
  end

private
  def aggregate
    @aggregator ||= []
  end

  def cursor
    @cursor ||= ThreadsafeCounter.new(-1)
  end
end
