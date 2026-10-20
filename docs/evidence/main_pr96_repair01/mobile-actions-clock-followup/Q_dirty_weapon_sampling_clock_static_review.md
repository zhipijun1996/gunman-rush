# Web weapon-motion clock: bounded static review

SCOPED_STATIC_ACCEPT for the exact production blob `2f4f750fb72da384995c1d36f22ae8bedf7587a0a25b3101a2581e32927cd909` atop Q `4aec8b56743d1a14d1b44ba43d795e56811d7615`. Reversing the deadline field, guard clock, deadline assignment and comment restores the entire original file byte for byte.

The unchanged real event payload now schedules from the same monotonic clock family used by `real_usec`. It emits actual current snapshots only; it does not synthesize missing samples, backdate observations or modify the consumer’s two-second assertion. Original motion eligibility, pause early return, game elapsed time, state and physics remain unchanged. Native execution short-circuits before the Web clock query.

The interval is at least 100ms when an eligible actual frame occurs, not a guaranteed 10Hz service. Slow-time serialization load increases and needs the original live consumers. This static acceptance neither establishes the cause of the earlier false result nor signs an unexecuted browser/test/public result.
