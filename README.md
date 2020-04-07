[![Build Status](https://travis-ci.org/spider-gazelle/simple_retry.svg?branch=master)](https://travis-ci.org/spider-gazelle/simple_retry)


# Simple Retry

A library for managing blocks of code that you might want to retry when an error occurs.


## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     simple_retry:
       github: spider-gazelle/simple_retry
   ```

2. Run `shards install`


## Usage

```crystal
require "simple_retry"

SimpleRetry.try_to do
  # Something that should succeed eventually
  num = rand(10)
  raise "bad number #{num}" if num < 5

  # Return the number
  num
end
```

There are a number of options you can use to customise

```crystal
require "simple_retry"

SimpleRetry.try_to(
  # Runs the block at most 5 times
  max_attempts: 5,
  # Will always stop retrying on these errors
  raise_on: DivisionByZeroError | ArgumentError,
  # Will only retry on these errors
  retry_on: Exception,
  # Initial delay time after first retry
  base_interval: 10.milliseconds,
  # Exponentially increase delay up to this period
  max_interval: 10.seconds,
  # Adjust the exponential growth by a random amount
  randomise: 10.milliseconds
) do |run_count : UInt64, last_error : Exception?, next_delay_time : Time::Span|
  # Something that should succeed
end
```
