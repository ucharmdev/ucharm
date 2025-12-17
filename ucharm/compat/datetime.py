# ucharm/compat/datetime.py
"""
Pure Python implementation of datetime for MicroPython.

Provides:
- datetime: Combined date and time
- date: Date only
- time: Time only (not to be confused with the time module)
- timedelta: Duration between two dates/times

Uses the built-in time module internally.
"""

import time as _time


def _zfill(s, width):
    """Zero-fill a string to the given width. MicroPython doesn't have str.zfill()."""
    s = str(s)
    if len(s) >= width:
        return s
    return "0" * (width - len(s)) + s


# Days in each month (non-leap year)
_DAYS_IN_MONTH = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

# Days before each month (cumulative, non-leap year)
_DAYS_BEFORE_MONTH = [0, 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]

# Weekday names
_WEEKDAY_NAMES = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
]
_WEEKDAY_ABBR = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

# Month names
_MONTH_NAMES = [
    "",
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
]
_MONTH_ABBR = [
    "",
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
]


def _is_leap(year):
    """Return True if year is a leap year."""
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)


def _days_in_month(year, month):
    """Return number of days in month for given year."""
    if month == 2 and _is_leap(year):
        return 29
    return _DAYS_IN_MONTH[month]


def _days_before_year(year):
    """Return number of days before January 1st of year."""
    y = year - 1
    return y * 365 + y // 4 - y // 100 + y // 400


def _days_before_month(year, month):
    """Return number of days before first day of month."""
    days = _DAYS_BEFORE_MONTH[month]
    if month > 2 and _is_leap(year):
        days += 1
    return days


def _ymd_to_ordinal(year, month, day):
    """Convert year, month, day to ordinal (days since day 1 of year 1)."""
    return _days_before_year(year) + _days_before_month(year, month) + day


def _ordinal_to_ymd(ordinal):
    """Convert ordinal to (year, month, day)."""
    # Use binary search to find the year
    # Start with an approximation
    n = ordinal
    y = n // 365

    while _days_before_year(y) >= n:
        y -= 1
    while _days_before_year(y + 1) < n:
        y += 1

    # Now y is correct, find day of year
    doy = n - _days_before_year(y)

    # Find month
    leap = _is_leap(y)
    for m in range(1, 13):
        dim = _DAYS_IN_MONTH[m] + (1 if m == 2 and leap else 0)
        if doy <= dim:
            return y, m, doy
        doy -= dim

    return y, 12, 31


class timedelta:
    """
    Represents a duration - the difference between two dates or times.

    timedelta(days=1, hours=2, minutes=30, seconds=15)
    """

    __slots__ = ("_days", "_seconds", "_microseconds")

    def __init__(
        self,
        days=0,
        seconds=0,
        microseconds=0,
        milliseconds=0,
        minutes=0,
        hours=0,
        weeks=0,
    ):
        # Convert everything to days, seconds, microseconds
        days = days + weeks * 7
        seconds = seconds + minutes * 60 + hours * 3600
        microseconds = microseconds + milliseconds * 1000

        # Normalize microseconds to seconds
        extra_seconds, microseconds = divmod(microseconds, 1000000)
        seconds += extra_seconds

        # Normalize seconds to days
        extra_days, seconds = divmod(seconds, 86400)
        days += extra_days

        # Store normalized values
        self._days = int(days)
        self._seconds = int(seconds)
        self._microseconds = int(microseconds)

    @property
    def days(self):
        return self._days

    @property
    def seconds(self):
        return self._seconds

    @property
    def microseconds(self):
        return self._microseconds

    def total_seconds(self):
        """Return total duration in seconds as a float."""
        return self._days * 86400 + self._seconds + self._microseconds / 1000000.0

    def __repr__(self):
        args = []
        if self._days:
            args.append("days=" + str(self._days))
        if self._seconds:
            args.append("seconds=" + str(self._seconds))
        if self._microseconds:
            args.append("microseconds=" + str(self._microseconds))
        return "datetime.timedelta(" + ", ".join(args) + ")"

    def __str__(self):
        # Format as [D day[s], ]H:MM:SS[.UUUUUU]
        parts = []

        if self._days:
            parts.append(
                str(self._days) + " day" + ("s" if abs(self._days) != 1 else "")
            )

        hours, remainder = divmod(self._seconds, 3600)
        minutes, seconds = divmod(remainder, 60)

        time_str = str(hours) + ":" + _zfill(minutes, 2) + ":" + _zfill(seconds, 2)
        if self._microseconds:
            time_str += "." + _zfill(self._microseconds, 6)

        parts.append(time_str)
        return ", ".join(parts)

    def __eq__(self, other):
        if isinstance(other, timedelta):
            return (
                self._days == other._days
                and self._seconds == other._seconds
                and self._microseconds == other._microseconds
            )
        return NotImplemented

    def __ne__(self, other):
        result = self.__eq__(other)
        if result is NotImplemented:
            return result
        return not result

    def __lt__(self, other):
        if isinstance(other, timedelta):
            return self._cmp(other) < 0
        return NotImplemented

    def __le__(self, other):
        if isinstance(other, timedelta):
            return self._cmp(other) <= 0
        return NotImplemented

    def __gt__(self, other):
        if isinstance(other, timedelta):
            return self._cmp(other) > 0
        return NotImplemented

    def __ge__(self, other):
        if isinstance(other, timedelta):
            return self._cmp(other) >= 0
        return NotImplemented

    def _cmp(self, other):
        """Compare two timedeltas, return -1, 0, or 1."""
        if self._days != other._days:
            return -1 if self._days < other._days else 1
        if self._seconds != other._seconds:
            return -1 if self._seconds < other._seconds else 1
        if self._microseconds != other._microseconds:
            return -1 if self._microseconds < other._microseconds else 1
        return 0

    def __add__(self, other):
        if isinstance(other, timedelta):
            return timedelta(
                days=self._days + other._days,
                seconds=self._seconds + other._seconds,
                microseconds=self._microseconds + other._microseconds,
            )
        return NotImplemented

    def __sub__(self, other):
        if isinstance(other, timedelta):
            return timedelta(
                days=self._days - other._days,
                seconds=self._seconds - other._seconds,
                microseconds=self._microseconds - other._microseconds,
            )
        return NotImplemented

    def __neg__(self):
        return timedelta(
            days=-self._days, seconds=-self._seconds, microseconds=-self._microseconds
        )

    def __pos__(self):
        return self

    def __abs__(self):
        if self._days < 0:
            return -self
        return self

    def __mul__(self, other):
        if isinstance(other, int):
            return timedelta(
                days=self._days * other,
                seconds=self._seconds * other,
                microseconds=self._microseconds * other,
            )
        return NotImplemented

    __rmul__ = __mul__

    def __bool__(self):
        return self._days != 0 or self._seconds != 0 or self._microseconds != 0

    def __hash__(self):
        return hash((self._days, self._seconds, self._microseconds))


# Common timedelta constants
timedelta.min = timedelta(days=-999999999)
timedelta.max = timedelta(
    days=999999999, hours=23, minutes=59, seconds=59, microseconds=999999
)
timedelta.resolution = timedelta(microseconds=1)


class date:
    """
    Represents a date (year, month, day).

    date(2024, 1, 15)
    """

    __slots__ = ("_year", "_month", "_day")

    def __init__(self, year, month, day):
        # Validate
        if not 1 <= month <= 12:
            raise ValueError("month must be in 1..12")
        dim = _days_in_month(year, month)
        if not 1 <= day <= dim:
            raise ValueError("day is out of range for month")

        self._year = year
        self._month = month
        self._day = day

    @property
    def year(self):
        return self._year

    @property
    def month(self):
        return self._month

    @property
    def day(self):
        return self._day

    @classmethod
    def today(cls):
        """Return current local date."""
        t = _time.localtime()
        return cls(t[0], t[1], t[2])

    @classmethod
    def fromtimestamp(cls, timestamp):
        """Create date from POSIX timestamp."""
        t = _time.localtime(timestamp)
        return cls(t[0], t[1], t[2])

    @classmethod
    def fromisoformat(cls, date_string):
        """Parse ISO format date string: YYYY-MM-DD."""
        parts = date_string.split("-")
        if len(parts) != 3:
            raise ValueError("Invalid isoformat string: " + date_string)
        return cls(int(parts[0]), int(parts[1]), int(parts[2]))

    @classmethod
    def fromordinal(cls, ordinal):
        """Create date from ordinal (days since year 1)."""
        y, m, d = _ordinal_to_ymd(ordinal)
        return cls(y, m, d)

    def toordinal(self):
        """Return ordinal (days since year 1)."""
        return _ymd_to_ordinal(self._year, self._month, self._day)

    def weekday(self):
        """Return day of week (0=Monday, 6=Sunday)."""
        return (self.toordinal() + 6) % 7

    def isoweekday(self):
        """Return day of week (1=Monday, 7=Sunday)."""
        return self.weekday() + 1

    def isocalendar(self):
        """Return (year, week, weekday) ISO calendar tuple."""
        ordinal = self.toordinal()
        weekday = self.weekday()

        # Find the Thursday of this week
        thursday = ordinal + (3 - weekday)

        # Find the first Thursday of the year
        jan1 = _ymd_to_ordinal(self._year, 1, 1)
        jan1_weekday = (jan1 + 6) % 7
        first_thursday = jan1 + (3 - jan1_weekday + 7) % 7

        # Calculate week number
        week = (thursday - first_thursday) // 7 + 1

        # Handle year boundaries
        if week < 1:
            # Previous year
            prev_jan1 = _ymd_to_ordinal(self._year - 1, 1, 1)
            prev_jan1_weekday = (prev_jan1 + 6) % 7
            prev_first_thursday = prev_jan1 + (3 - prev_jan1_weekday + 7) % 7
            week = (thursday - prev_first_thursday) // 7 + 1
            return (self._year - 1, week, weekday + 1)

        # Check if it belongs to next year
        dec31 = _ymd_to_ordinal(self._year, 12, 31)
        dec31_weekday = (dec31 + 6) % 7
        if dec31_weekday < 3 and ordinal > dec31 - dec31_weekday:
            return (self._year + 1, 1, weekday + 1)

        return (self._year, week, weekday + 1)

    def isoformat(self):
        """Return ISO format string: YYYY-MM-DD."""
        return (
            _zfill(self._year, 4)
            + "-"
            + _zfill(self._month, 2)
            + "-"
            + _zfill(self._day, 2)
        )

    def __str__(self):
        return self.isoformat()

    def __repr__(self):
        return (
            "datetime.date("
            + str(self._year)
            + ", "
            + str(self._month)
            + ", "
            + str(self._day)
            + ")"
        )

    def strftime(self, fmt):
        """Format date according to format string."""
        return _strftime(fmt, self._year, self._month, self._day, 0, 0, 0, 0)

    def replace(self, year=None, month=None, day=None):
        """Return date with specified fields replaced."""
        return date(
            year if year is not None else self._year,
            month if month is not None else self._month,
            day if day is not None else self._day,
        )

    def __eq__(self, other):
        if isinstance(other, date):
            return (
                self._year == other._year
                and self._month == other._month
                and self._day == other._day
            )
        return NotImplemented

    def __lt__(self, other):
        if isinstance(other, date):
            return self.toordinal() < other.toordinal()
        return NotImplemented

    def __le__(self, other):
        if isinstance(other, date):
            return self.toordinal() <= other.toordinal()
        return NotImplemented

    def __gt__(self, other):
        if isinstance(other, date):
            return self.toordinal() > other.toordinal()
        return NotImplemented

    def __ge__(self, other):
        if isinstance(other, date):
            return self.toordinal() >= other.toordinal()
        return NotImplemented

    def __add__(self, other):
        if isinstance(other, timedelta):
            return date.fromordinal(self.toordinal() + other.days)
        return NotImplemented

    def __sub__(self, other):
        if isinstance(other, timedelta):
            return date.fromordinal(self.toordinal() - other.days)
        if isinstance(other, date):
            return timedelta(days=self.toordinal() - other.toordinal())
        return NotImplemented

    def __hash__(self):
        return hash((self._year, self._month, self._day))


class datetime(date):
    """
    Represents a date and time.

    datetime(2024, 1, 15, 14, 30, 0)
    """

    __slots__ = ("_hour", "_minute", "_second", "_microsecond", "_tzinfo")

    def __init__(
        self, year, month, day, hour=0, minute=0, second=0, microsecond=0, tzinfo=None
    ):
        super().__init__(year, month, day)

        if not 0 <= hour <= 23:
            raise ValueError("hour must be in 0..23")
        if not 0 <= minute <= 59:
            raise ValueError("minute must be in 0..59")
        if not 0 <= second <= 59:
            raise ValueError("second must be in 0..59")
        if not 0 <= microsecond <= 999999:
            raise ValueError("microsecond must be in 0..999999")

        self._hour = hour
        self._minute = minute
        self._second = second
        self._microsecond = microsecond
        self._tzinfo = tzinfo

    @property
    def hour(self):
        return self._hour

    @property
    def minute(self):
        return self._minute

    @property
    def second(self):
        return self._second

    @property
    def microsecond(self):
        return self._microsecond

    @property
    def tzinfo(self):
        return self._tzinfo

    @classmethod
    def now(cls, tz=None):
        """Return current local datetime."""
        t = _time.localtime()
        return cls(t[0], t[1], t[2], t[3], t[4], t[5], 0, tz)

    @classmethod
    def utcnow(cls):
        """Return current UTC datetime."""
        t = _time.gmtime()
        return cls(t[0], t[1], t[2], t[3], t[4], t[5])

    @classmethod
    def today(cls):
        """Return current local datetime."""
        return cls.now()

    @classmethod
    def fromtimestamp(cls, timestamp, tz=None):
        """Create datetime from POSIX timestamp."""
        t = _time.localtime(timestamp)
        return cls(t[0], t[1], t[2], t[3], t[4], t[5], 0, tz)

    @classmethod
    def utcfromtimestamp(cls, timestamp):
        """Create UTC datetime from POSIX timestamp."""
        t = _time.gmtime(timestamp)
        return cls(t[0], t[1], t[2], t[3], t[4], t[5])

    @classmethod
    def fromisoformat(cls, date_string):
        """Parse ISO format datetime string."""
        # Handle date only
        if "T" not in date_string and " " not in date_string:
            d = date.fromisoformat(date_string)
            return cls(d.year, d.month, d.day)

        # Split date and time
        if "T" in date_string:
            date_part, time_part = date_string.split("T")
        else:
            date_part, time_part = date_string.split(" ")

        # Parse date
        d = date.fromisoformat(date_part)

        # Parse time
        microsecond = 0
        if "." in time_part:
            time_part, us_part = time_part.split(".")
            # Handle timezone suffix
            for tz_char in ["+", "-", "Z"]:
                if tz_char in us_part:
                    us_part = us_part.split(tz_char)[0]
                    break
            microsecond = int((us_part + "000000")[:6])

        time_parts = time_part.split(":")
        hour = int(time_parts[0])
        minute = int(time_parts[1]) if len(time_parts) > 1 else 0
        second = (
            int(time_parts[2].split("+")[0].split("-")[0].split("Z")[0])
            if len(time_parts) > 2
            else 0
        )

        return cls(d.year, d.month, d.day, hour, minute, second, microsecond)

    @classmethod
    def combine(cls, date_obj, time_obj, tzinfo=None):
        """Combine date and time into datetime."""
        if tzinfo is None and hasattr(time_obj, "tzinfo"):
            tzinfo = time_obj.tzinfo
        return cls(
            date_obj.year,
            date_obj.month,
            date_obj.day,
            time_obj.hour,
            time_obj.minute,
            time_obj.second,
            time_obj.microsecond,
            tzinfo,
        )

    def date(self):
        """Return date part."""
        return date(self._year, self._month, self._day)

    def time(self):
        """Return time part (without tzinfo)."""
        return time(self._hour, self._minute, self._second, self._microsecond)

    def timetz(self):
        """Return time part (with tzinfo)."""
        return time(
            self._hour, self._minute, self._second, self._microsecond, self._tzinfo
        )

    def timestamp(self):
        """Return POSIX timestamp."""
        # Create time tuple
        tt = (
            self._year,
            self._month,
            self._day,
            self._hour,
            self._minute,
            self._second,
            0,
            0,
            -1,
        )
        return _time.mktime(tt) + self._microsecond / 1000000.0

    def isoformat(self, sep="T", timespec="auto"):
        """Return ISO format string."""
        date_str = super().isoformat()

        if timespec == "hours":
            time_str = _zfill(self._hour, 2)
        elif timespec == "minutes":
            time_str = _zfill(self._hour, 2) + ":" + _zfill(self._minute, 2)
        elif timespec == "seconds":
            time_str = (
                _zfill(self._hour, 2)
                + ":"
                + _zfill(self._minute, 2)
                + ":"
                + _zfill(self._second, 2)
            )
        elif timespec == "milliseconds":
            time_str = (
                _zfill(self._hour, 2)
                + ":"
                + _zfill(self._minute, 2)
                + ":"
                + _zfill(self._second, 2)
                + "."
                + _zfill(self._microsecond // 1000, 3)
            )
        elif timespec == "microseconds":
            time_str = (
                _zfill(self._hour, 2)
                + ":"
                + _zfill(self._minute, 2)
                + ":"
                + _zfill(self._second, 2)
                + "."
                + _zfill(self._microsecond, 6)
            )
        else:  # auto
            time_str = (
                _zfill(self._hour, 2)
                + ":"
                + _zfill(self._minute, 2)
                + ":"
                + _zfill(self._second, 2)
            )
            if self._microsecond:
                time_str += "." + _zfill(self._microsecond, 6)

        return date_str + sep + time_str

    def __str__(self):
        return self.isoformat(" ")

    def __repr__(self):
        args = [
            str(self._year),
            str(self._month),
            str(self._day),
            str(self._hour),
            str(self._minute),
            str(self._second),
        ]
        if self._microsecond:
            args.append(str(self._microsecond))
        return "datetime.datetime(" + ", ".join(args) + ")"

    def strftime(self, fmt):
        """Format datetime according to format string."""
        return _strftime(
            fmt,
            self._year,
            self._month,
            self._day,
            self._hour,
            self._minute,
            self._second,
            self._microsecond,
        )

    def replace(
        self,
        year=None,
        month=None,
        day=None,
        hour=None,
        minute=None,
        second=None,
        microsecond=None,
        tzinfo=None,
    ):
        """Return datetime with specified fields replaced."""
        return datetime(
            year if year is not None else self._year,
            month if month is not None else self._month,
            day if day is not None else self._day,
            hour if hour is not None else self._hour,
            minute if minute is not None else self._minute,
            second if second is not None else self._second,
            microsecond if microsecond is not None else self._microsecond,
            tzinfo if tzinfo is not None else self._tzinfo,
        )

    def __eq__(self, other):
        if isinstance(other, datetime):
            return (
                super().__eq__(other)
                and self._hour == other._hour
                and self._minute == other._minute
                and self._second == other._second
                and self._microsecond == other._microsecond
            )
        return NotImplemented

    def __lt__(self, other):
        if isinstance(other, datetime):
            if super().__eq__(other):
                if self._hour != other._hour:
                    return self._hour < other._hour
                if self._minute != other._minute:
                    return self._minute < other._minute
                if self._second != other._second:
                    return self._second < other._second
                return self._microsecond < other._microsecond
            return super().__lt__(other)
        return NotImplemented

    def __add__(self, other):
        if isinstance(other, timedelta):
            # Convert to timestamp, add, convert back
            total_us = (
                self._microsecond
                + other._microseconds
                + (self._second + other._seconds) * 1000000
                + (self._minute * 60 + self._hour * 3600) * 1000000
            )

            days = self.toordinal() + other._days

            # Handle overflow from time
            days_from_us, total_us = divmod(total_us, 86400 * 1000000)
            days += days_from_us

            # Convert back to components
            total_s, us = divmod(total_us, 1000000)
            total_m, s = divmod(total_s, 60)
            h, m = divmod(total_m, 60)

            y, mo, d = _ordinal_to_ymd(days)
            return datetime(y, mo, d, h, m, s, us, self._tzinfo)
        return NotImplemented

    def __sub__(self, other):
        if isinstance(other, timedelta):
            return self + (-other)
        if isinstance(other, datetime):
            days = self.toordinal() - other.toordinal()
            seconds = (
                (self._hour - other._hour) * 3600
                + (self._minute - other._minute) * 60
                + (self._second - other._second)
            )
            microseconds = self._microsecond - other._microsecond
            return timedelta(days=days, seconds=seconds, microseconds=microseconds)
        return NotImplemented

    def __hash__(self):
        return hash(
            (
                self._year,
                self._month,
                self._day,
                self._hour,
                self._minute,
                self._second,
                self._microsecond,
            )
        )


class time:
    """
    Represents a time of day.

    time(14, 30, 0)
    """

    __slots__ = ("_hour", "_minute", "_second", "_microsecond", "_tzinfo")

    def __init__(self, hour=0, minute=0, second=0, microsecond=0, tzinfo=None):
        if not 0 <= hour <= 23:
            raise ValueError("hour must be in 0..23")
        if not 0 <= minute <= 59:
            raise ValueError("minute must be in 0..59")
        if not 0 <= second <= 59:
            raise ValueError("second must be in 0..59")
        if not 0 <= microsecond <= 999999:
            raise ValueError("microsecond must be in 0..999999")

        self._hour = hour
        self._minute = minute
        self._second = second
        self._microsecond = microsecond
        self._tzinfo = tzinfo

    @property
    def hour(self):
        return self._hour

    @property
    def minute(self):
        return self._minute

    @property
    def second(self):
        return self._second

    @property
    def microsecond(self):
        return self._microsecond

    @property
    def tzinfo(self):
        return self._tzinfo

    @classmethod
    def fromisoformat(cls, time_string):
        """Parse ISO format time string."""
        microsecond = 0
        if "." in time_string:
            time_string, us_part = time_string.split(".")
            microsecond = int((us_part + "000000")[:6])

        parts = time_string.split(":")
        hour = int(parts[0])
        minute = int(parts[1]) if len(parts) > 1 else 0
        second = int(parts[2]) if len(parts) > 2 else 0

        return cls(hour, minute, second, microsecond)

    def isoformat(self, timespec="auto"):
        """Return ISO format string."""
        if timespec == "hours":
            return _zfill(self._hour, 2)
        elif timespec == "minutes":
            return _zfill(self._hour, 2) + ":" + _zfill(self._minute, 2)
        elif timespec == "seconds":
            return (
                _zfill(self._hour, 2)
                + ":"
                + _zfill(self._minute, 2)
                + ":"
                + _zfill(self._second, 2)
            )
        elif timespec == "milliseconds":
            return (
                _zfill(self._hour, 2)
                + ":"
                + _zfill(self._minute, 2)
                + ":"
                + _zfill(self._second, 2)
                + "."
                + _zfill(self._microsecond // 1000, 3)
            )
        elif timespec == "microseconds":
            return (
                _zfill(self._hour, 2)
                + ":"
                + _zfill(self._minute, 2)
                + ":"
                + _zfill(self._second, 2)
                + "."
                + _zfill(self._microsecond, 6)
            )
        else:  # auto
            result = (
                _zfill(self._hour, 2)
                + ":"
                + _zfill(self._minute, 2)
                + ":"
                + _zfill(self._second, 2)
            )
            if self._microsecond:
                result += "." + _zfill(self._microsecond, 6)
            return result

    def __str__(self):
        return self.isoformat()

    def __repr__(self):
        args = [str(self._hour), str(self._minute), str(self._second)]
        if self._microsecond:
            args.append(str(self._microsecond))
        return "datetime.time(" + ", ".join(args) + ")"

    def strftime(self, fmt):
        """Format time according to format string."""
        return _strftime(
            fmt, 1900, 1, 1, self._hour, self._minute, self._second, self._microsecond
        )

    def replace(
        self, hour=None, minute=None, second=None, microsecond=None, tzinfo=None
    ):
        """Return time with specified fields replaced."""
        return time(
            hour if hour is not None else self._hour,
            minute if minute is not None else self._minute,
            second if second is not None else self._second,
            microsecond if microsecond is not None else self._microsecond,
            tzinfo if tzinfo is not None else self._tzinfo,
        )

    def __eq__(self, other):
        if isinstance(other, time):
            return (
                self._hour == other._hour
                and self._minute == other._minute
                and self._second == other._second
                and self._microsecond == other._microsecond
            )
        return NotImplemented

    def __lt__(self, other):
        if isinstance(other, time):
            return (self._hour, self._minute, self._second, self._microsecond) < (
                other._hour,
                other._minute,
                other._second,
                other._microsecond,
            )
        return NotImplemented

    def __hash__(self):
        return hash((self._hour, self._minute, self._second, self._microsecond))

    def __bool__(self):
        return True


def _strftime(fmt, year, month, day, hour, minute, second, microsecond):
    """Simple strftime implementation."""
    # Calculate weekday
    ordinal = _ymd_to_ordinal(year, month, day)
    weekday = (ordinal + 6) % 7

    # Calculate day of year
    doy = _days_before_month(year, month) + day

    result = fmt

    # Replace format codes (order matters - longer codes first)
    result = result.replace("%Y", _zfill(year, 4))
    result = result.replace("%y", _zfill(year % 100, 2))
    result = result.replace("%m", _zfill(month, 2))
    result = result.replace("%d", _zfill(day, 2))
    result = result.replace("%H", _zfill(hour, 2))
    result = result.replace("%I", _zfill((hour % 12) or 12, 2))
    result = result.replace("%M", _zfill(minute, 2))
    result = result.replace("%S", _zfill(second, 2))
    result = result.replace("%f", _zfill(microsecond, 6))
    result = result.replace("%p", "AM" if hour < 12 else "PM")
    result = result.replace("%j", _zfill(doy, 3))
    result = result.replace("%w", str((weekday + 1) % 7))
    result = result.replace("%a", _WEEKDAY_ABBR[weekday])
    result = result.replace("%A", _WEEKDAY_NAMES[weekday])
    result = result.replace("%b", _MONTH_ABBR[month])
    result = result.replace("%B", _MONTH_NAMES[month])
    result = result.replace("%%", "%")

    return result


# Timezone constants (simplified - no real timezone support)
MINYEAR = 1
MAXYEAR = 9999
