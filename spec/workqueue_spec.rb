describe WorkQueue do

  before do
    # a helper mutex
    @mutex = Mutex.new
  end

  it 'preserves order of results' do
    queue = WorkQueue.new([1,2,3]) do |x|
      # the sleep ensures they actually run in opposite order
      sleep(0.5 - 0.1*x)
      x + 1
    end.run

    assert { queue.results == [2, 3, 4] }
  end

  it 'passes the index into the block' do
    queue = WorkQueue.new([1,2,3]) do |x, i|
      # the sleep ensures they actually run in opposite order
      sleep(0.5 - 0.1*x)
      x + i
    end.run

    assert { queue.results == [1, 3, 5] }
  end

  it %[doesn't do anything unless #run is called] do
    aggregator = []

    queue = WorkQueue.new([1,2,3]) do |x|
      @mutex.synchronize { aggregator << x + 1 }
    end

    aggregator << 0

    assert { queue.results == [] }

    queue.run

    # aggregator is undefined here, since we're
    # running parallel to the workers...

    # so let's join them!
    # (calling #results also does this)
    queue.join

    assert { aggregator.sort == [0, 2, 3, 4] }
  end

  it %[bubbles up exceptions] do
    queue = WorkQueue.new([1,2,3]) do |x|
      raise "got an even number" if x.even?
    end.run

    ex = rescuing { queue.join }

    assert { ex }
    assert { ex.message == "got an even number" }
    assert { ex.backtrace.grep(/work!/).any? }
  end
end
