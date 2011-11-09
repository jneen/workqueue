require 'thread'

class WorkQueue
  class ThreadsafeCounter
    def initialize(count=0)
      @count = count
      @mutex = Mutex.new
    end

    def incr(by=1)
      @mutex.synchronize { @count += by }
    end
  end

  attr_reader :queue
  attr_reader :job
  def initialize(init_queue=[], opts={}, &job)
    @job = job
    @queue = Queue.new
    @mutex = Mutex.new

    opts.each { |k, v| send(:"#{k}=", v) }

    concat(init_queue)
  end

  attr_writer :size
  def size
    @size ||= 2
  end

  def work!
    loop do
      begin
        unless @aborted
          payload, index = queue.shift
        end

        break if payload.nil?

        aggregate[index] = job.call(payload)
      rescue Exception
        abort!
        raise
      end
    end
  end

  def abort!
    @mutex.synchronize { @aborted = true }
  end

  def run
    @workers = (1..size).map do
      Thread.new { work! }
    end

    self
  end

  def push(e)
    queue.push([e, cursor.incr])

    self
  end
  alias << push

  def concat(arr)
    arr.each { |x| push(x) }
  end

  def join
    concat([nil] * size)

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

  def workers
    @workers ||= []
  end
end
