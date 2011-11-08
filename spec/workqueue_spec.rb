describe WorkQueue do
  it 'preserves order' do
    queue = WorkQueue.new([1,2,3]) do |x|
      # the sleep ensures they actually run in opposite order
      sleep 0.5 - 0.1*x
      x + 1
    end.run

    assert { queue.results == [2, 3, 4] }
  end
end
