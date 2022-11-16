'''
Status class to manage returns
'''


class Status(int):
    """
    This class inherits from int (interpreted as a return value) to add an error message
    >>> e = Status("ok")
    >>> print(e, e.msg)
    0 ok
    >>> e = Status("something bad happened")
    >>> print(e, e.msg)
    1 something bad happened
    >>> e = Status(777)
    >>> print(e, e.msg)
    777 777
    """
    msg = ""

    def __new__(cls, str_or_int):
        if isinstance(str_or_int, str):
            value = 0 if str_or_int == "ok" else 1
        elif isinstance(str_or_int, int):
            value = int(str_or_int)
        obj = super().__new__(cls, value)
        obj.msg = str(str_or_int)
        return obj
