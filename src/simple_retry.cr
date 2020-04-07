module SimpleRetry
  # Allow the module methods to be called directly
  extend SimpleRetry

  private def error_matches?(klass : Exception.class, error : Exception)
    klass >= error.class
  end

  ZERO_SECONDS = 0.seconds

  def try_to(
    max_attempts : Int? = nil,
    retry_on : Exception.class | Nil = nil,
    raise_on : Exception.class | Nil = nil
  )
    attempt = 1_u64
    last_error = nil

    loop do
      begin
        break yield(attempt, last_error, ZERO_SECONDS)
      rescue error
        raise error if max_attempts && attempt >= max_attempts
        raise error if retry_on && !error_matches?(retry_on, error)
        raise error if raise_on && error_matches?(raise_on, error)
        last_error = error

        Fiber.yield

        # we don't want to error if we overflow
        attempt = attempt &+ 1
      end
    end
  end

  def try_to(
    max_attempts : Int? = nil,
    retry_on : Exception.class | Nil = nil,
    raise_on : Exception.class | Nil = nil,
    max_interval : Time::Span? = nil,
    base_interval : Time::Span = 50.milliseconds
  )
    attempt = 1_u64
    last_error = nil
    retry_in = 0.seconds

    loop do
      begin
        break yield(attempt, last_error, retry_in)
      rescue error
        raise error if max_attempts && attempt >= max_attempts
        raise error if retry_on && !error_matches?(retry_on, error)
        raise error if raise_on && error_matches?(raise_on, error)
        last_error = error

        sleep retry_in

        # we don't want to error if we overflow
        attempt = attempt &+ 1

        if retry_in.to_f == 0_f64
          retry_in = base_interval
        else
          begin
            retry_in = retry_in * 2
          rescue OverflowError
            # you're waiting a long time if you hit this
          end
        end

        retry_in = max_interval if max_interval && retry_in > max_interval
      end
    end
  end

  def try_to(
    randomise : Time::Span,
    max_attempts : Int? = nil,
    retry_on : Exception.class | Nil = nil,
    raise_on : Exception.class | Nil = nil,
    max_interval : Time::Span? = nil,
    base_interval : Time::Span = 50.milliseconds
  )
    if max_interval && randomise > max_interval
      raise "max_interval (#{max_interval}) must be greater than randomise (#{randomise})"
    end

    attempt = 1_u64
    last_error = nil
    retry_in = 0.seconds
    randomise = randomise.total_seconds

    loop do
      begin
        break yield(attempt, last_error, retry_in)
      rescue error
        raise error if max_attempts && attempt >= max_attempts
        raise error if retry_on && !error_matches?(retry_on, error)
        raise error if raise_on && error_matches?(raise_on, error)
        last_error = error

        sleep retry_in

        # we don't want to error if we overflow
        attempt = attempt &+ 1
        random_time = Random.rand(randomise).seconds

        begin
          if retry_in.to_f == 0_f64
            retry_in = base_interval + random_time
          else
            retry_in = retry_in * 2 + random_time
          end
        rescue OverflowError
          # you're waiting a long time if you hit this
        end

        if max_interval && retry_in > max_interval
          retry_in = max_interval - random_time
        end
      end
    end
  end
end
