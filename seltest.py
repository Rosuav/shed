# Partially borrowed from example in Python docs:
# https://docs.python.org/3/library/selectors.html#examples
import selectors
import socket
import time

sel = selectors.DefaultSelector()
sleepers = {} # In a non-toy, this would probably be a heap, not a dict
def eventloop():
    while "loop forever":
        t = time.time()
        for gen, tm in list(sleepers.items()):
            if tm <= t:
                del sleepers[gen]
                run_task(gen)
        delay = min(sleepers.values(), default=t+3600) - t
        if delay < 0: continue
        for key, mask in sel.select(timeout=delay):
            sel.unregister(key.fileobj)
            run_task(key.data)

def run_task(gen):
    try:
        waitfor = next(gen)
        if isinstance(waitfor, float):
            sleepers[gen] = waitfor
        else:
            sel.register(waitfor, selectors.EVENT_READ, gen)
    except StopIteration:
        pass

def sleep(tm):
    yield time.time() + tm

def mainsock():
    sock = socket.socket()
    sock.bind(('localhost', 1234))
    sock.listen(100)
    sock.setblocking(False)
    print("Listening on port 1234.")
    while "moar sockets":
        yield sock
        conn, addr = sock.accept()  # Should be ready
        print('accepted', conn, 'from', addr)
        conn.setblocking(False)
        run_task(client(conn))

def client(conn):
    while "moar data":
        yield conn
        data = conn.recv(1000)  # Should be ready
        if not data: break
        print("Got data")
        # At this point, you'd do something smart with the data.
        # But we don't. We just echo back, after a delay.
        yield from sleep(3)
        conn.send(data)  # Hope it won't block
        if b"quit" in data: break
    print('closing', conn)
    conn.close()

def daprano():
    import random
    def work(id):
        print("starting with id", id)
        workload = random.randint(5, 15)
        for i in range(workload):
            yield from sleep(0.2)  # pretend to do some real work
            print("processing id", id)  # let the user see some progress
        print("done with id", id)
        return 10 + id

    for n in [1, 2, 3, 4]:
        run_task(work(n))

if __name__ == '__main__':
    run_task(mainsock())
    # daprano()
    eventloop()
