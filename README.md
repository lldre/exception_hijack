This repository contains 2 source files for displaying the Exception Hijacking technique explained in this article: https://saza.re/exception_hijacking/

The compiled version is there for convenience, if you want to compile the example yourself from source issue the following commands inside the 64-bit visual studio build tools command prompt:
```
> ml64 /c boobytrap.s
> cl exception_hijack.c boobytrap.obj
```

# Disclaimer
The files and research presented here are purely for educational purposes only. I cannot be held liable for any damages resulting from the use of the code or research presented here. Please use common sense :)
