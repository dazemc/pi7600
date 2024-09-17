CC=g++
DLIBS=-lbcm2835 -lrt -lpthread
OBJS= SMS.o ../lib/arduPi.o ../lib/sim7x00.o
SMS:$(OBJS) 
	$(CC) -Wall -o SMS $(OBJS)  $(DLIBS) 

%.o:%.c
	$(CC) -c -o $@ $<

clean:
	rm -f *.o SMS

