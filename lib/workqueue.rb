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
  attr_reader :aggregate
  attr_reader :cursor
  attr_reader :workers
  def initialize(init_queue=[], opts={}, &job)
    @job = job
    @queue = Queue.new
    @aggregate = []
    @cursor = ThreadsafeCounter.new(-1)
    @aggregate_mutex = Mutex.new

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
        break if @aborted
        payload = queue.shift
        break if payload == :__break!

        el, index = payload
        result = job.call(el, index)

        @aggregate_mutex.synchronize { aggregate[index] = result }
      rescue Exception => e
        Thread.current[:exception] = e
        abort!
      end
    end
  end

  def abort!
    @aborted = true
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
    concat([:__break!] * size)

    workers.each(&:join)

    exception = workers.map { |w| w[:exception] }.compact.first
    raise exception if exception

    self
  end

  def results
    join
    aggregate
  end
end
