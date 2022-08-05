/*
// Poof of concept code for abusing the exception handling logic
// inside of ntdll to hide code and data flow.
//
// This code and research was done by:              lldre
// Link to a blog post explaining this technique:   https://saza.re/exception_hijacking/
//
//
// DISCLAIMER: This proof of concept is for educational purposes only, I am
//             not liable for any misuse or abuse resulting from it.
//
*/

#include <windows.h>
#include <stdio.h>


void
main(int argc, char** argv)
{

/*
    Get the variable that will be used to store the first
    value in our calculation. We will take the address of this
    value and use it to access the second value as well. Eventually
    we pass the address to our calc function.

    NOTE: This is where we provide calc with an address inside the data
          section that our exception handler can later use to reference
          other members in the data section
*/ 
    extern __int64 first_val;
    int result;

    if (argc != 4)
    {
        printf("Usage: <exe> [16-bit number] [+|-|/] [16-bit number]\n");
        exit(-1);
    }

/*
    Get our calculator values from the cmdline args
*/
    (&first_val)[0] = atoi(argv[1]);
    (&first_val)[1] = atoi(argv[3]);

/*
    Check if our values fit inside of a word, so we don't
    run into integer overflow issues inside of our calc code.
*/
    if ( (&first_val)[0] > 0xFFFF || (&first_val)[1] > 0xFFFF)
    {
        printf("Error: values too big\n");
        exit(-1);
    }

    result = calc(&first_val, argv[2]);
    printf("result: %d\n", result);
    
    return;
}