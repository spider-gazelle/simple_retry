module SimpleRetry
  # Allow the module methods to be called directly
  extend SimpleRetry

  private def error_matches?(klass : Exception.class, error : Exception)
    klass >= error.class
  end

  private ZERO_SECONDS = 0.seconds

  # Immediate retry
  def try_to(
    max_attempts : Int? = nil,
    retry_on : Exception.class | Nil = nil,
    raise_on : Exception.class | Nil = nil,
    & : (UInt64, Exception?, Time::Span) ->
  )
    try_to(base_interval: ZERO_SECONDS, max_attempts: max_attempts, retry_on: retry_on, raise_on: raise_on) do |a, l, i|
      yield(a, l, i)
    end
  end

  # Retry with backoff
  #
  # ameba:disable Metrics/CyclomaticComplexity
  def try_to(
    base_interval : Time::Span,
    retry_on : Exception.class | Nil = nil,
    raise_on : Exception.class | Nil = nil,
    max_attempts : Int? = nil,
    max_interval : Time::Span? = nil,
    max_elapsed_time : Time::Span? = nil,
    randomise : Time::Span? = nil,
    & : (UInt64, Exception?, Time::Span) ->
  )
    attempt = 1_u64
    last_error = nil
    retry_in = ZERO_SECONDS
    start_time = Time.monotonic

    # The range of seconds to generate a random offset within
    random_seconds = !randomise.nil? ? randomise.total_seconds : nil

    loop do
      begin
        break yield(attempt, last_error, retry_in)
      rescue error
        raise error if max_attempts && attempt >= max_attempts
        raise error if retry_on && !error_matches?(retry_on, error)
        raise error if raise_on && error_matches?(raise_on, error)

        elapsed_time = Time.monotonic - start_time

        # Calculate a random offset, if necessary
        random_offset = !random_seconds.nil? ? Random.rand(random_seconds).seconds : nil
        retry_in = calculate_interval(retry_in, base_interval, random_offset, max_interval)

        raise error if max_elapsed_time && (elapsed_time + retry_in) > max_elapsed_time

        last_error = error

        sleep retry_in

        # we don't want to error if we overflow
        attempt = attempt &+ 1
      end
    end
  end

  # Calculate the next interval
  #
  private def calculate_interval(current_interval : Time::Span, base_interval : Time::Span, offset : Time::Span? = nil, max_interval : Time::Span? = nil)
    interval = if current_interval.to_f == 0_f64
                 base_interval
               else
                 current_interval * 2
               end

    interval += offset if offset

    if max_interval && interval > max_interval
      interval = max_interval
      interval -= offset if offset
    end

    interval
  rescue OverflowError
    # You've waiting a long time if you hit this
    ZERO_SECONDS
  end
end
