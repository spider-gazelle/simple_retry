require "./spec_helper"

describe SimpleRetry do
  it "performs a basic retry" do
    final_count = SimpleRetry.try_to do |count|
      raise "some issue" if count < 5
      count
    end
    final_count.should eq(5)
  end

  it "does not retry on specified errors" do
    final_count = 0
    expect_raises(DivisionByZeroError) do
      SimpleRetry.try_to(raise_on: DivisionByZeroError) do |count|
        raise "some issue" if count < 5
        final_count = count
        count // 0
        count
      end
    end
    final_count.should eq(5)
  end

  it "retries on specified errors" do
    final_count = 0
    expect_raises(Exception) do
      SimpleRetry.try_to(retry_on: DivisionByZeroError) do |count|
        final_count = count
        count // 0 if count < 3
        raise "different error"
        count
      end
    end
    final_count.should eq(3)
  end

  it "only retries a certain number of times" do
    final_count = 0
    expect_raises(Exception) do
      SimpleRetry.try_to(max_attempts: 5) do |count|
        final_count = count
        raise "some issue"
        count
      end
    end
    final_count.should eq(5)
  end

  it "backs off exponentially" do
    times = [] of Time::Span
    final_count = SimpleRetry.try_to(
      base_interval: 10.milliseconds,
      max_interval: 50.milliseconds
    ) do |count, _, sleep_time|
      times << sleep_time
      raise "some issue" if count < 7
      count
    end
    final_count.should eq(7)
    times.should eq([
      0.milliseconds,
      10.milliseconds,
      20.milliseconds,
      40.milliseconds,
      50.milliseconds,
      50.milliseconds,
      50.milliseconds,
    ])
  end

  it "backs off exponentially with some randomness" do
    times = [] of Time::Span
    final_count = SimpleRetry.try_to(
      randomise: 9.milliseconds,
      base_interval: 10.milliseconds,
      max_interval: 50.milliseconds
    ) do |count, _, sleep_time|
      times << sleep_time
      raise "some issue" if count < 7
      count
    end
    final_count.should eq(7)

    [
      0.milliseconds,
      10.milliseconds,
      20.milliseconds,
      40.milliseconds,
      50.milliseconds,
      50.milliseconds,
      50.milliseconds,
    ].each_with_index do |value, index|
      # The wait time is never greater than `max_interval`
      if value == 50.milliseconds
        (value >= times[index]).should eq(true)
      else
        (value <= times[index]).should eq(true)
      end
    end
  end
end
