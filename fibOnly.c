int
fib(int n)
{
    if(n < 2)
	return(n);
    
    return(fib(n-1) + fib(n-2));
}


extern double log(double);

double
mylog(double val)
{
    return(log(val));
}


const char *MonthNames[] = { "January", "February", "March","April", "May", "June", "July", "August", "September", "October", "November", "December"};

const char *
monthName(int val)
{
    return(MonthNames[val - 1]);
}
