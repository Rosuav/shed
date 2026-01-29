NOTE: This is written up as a game design, but the game itself isn't the
primary goal here, so I don't mind if it doesn't end up being fun to play.
The goal here is to have a full design planned out, THEN pick up a game
engine (probably Godot), and try to implement it - that is, the true goal
here is mastery of the engine, not the game produced along the way. Can I
make this happen, and to what extent will the engine force me to change my
design during implementation?

Though, that said, if anyone knows of a game that is basically this, please
let me know; I want to learn from it.

Number Makers
=============

You are in command of a number factory on a remote site. Everything there is
operated by robots, and you send the robots high-level commands which they
then execute. You are constructing a factory, module by module, to build
numbers to a predefined specification.

Building a number
-----------------

At the start of the game, you have access to:

* Primaries. The digits 1 through 9 are available in vast supply, and cost
  you a single time unit to fetch.
* Laser cutter. It takes a number and slices off just one tenth, one hundredth,
  or one thousandth, of that number. Takes one time unit.
* Combiner. Takes up to four numbers and adds them together. Takes one time unit.

After a few missions, you'll unlock other machines.

* Transporter. Take the output from a previously-designed module. Its time cost
  is the cost of production at that module, plus an additional delivery time.
* Primal Dissolution. Takes a number and divides it by a small prime - 2, 3, 5,
  7, and maybe more later.
* Additional primaries? Like e or pi.

You design a module by placing machines, and specifying their inputs and outputs.
An input could be any primary, or it could be belted in from another machine.
Similarly, the output can be belted into another machine, or it could be the
final output for the module (which will be a fixed location, probably top middle
of the screen).

When you're ready, you activate the module in test mode, which runs it at a slow
clock so you can watch everything. It first gathers all the primaries, and starts
all machines. A machine that has all its inputs begins to operate, takes its time,
and produces its output. Belts are reasonably fast, but they do take some time.
If the final output is correct, the module remembers a total time cost, and is
now viable!

Gameplay
--------

Your attention is mostly going to be on designing modules, but then the game will
run by itself with productivity defined by the time cost of the modules. As the
game progresses, you will have more and more requirements, like "produce five
thousand of 0.707483" and possibly multiple concurrent goals. Completing these
goals unlocks new content (call it research or whatever).

At first, you'll be able to brute-force your numbers by just scaling primaries and
combining them. However, there will usually be a different way to do it too. And
as the numbers get longer, that will become harder; the scaling module might need
to slow down if it's scaling more digits or something.

The goal numbers will always be designed to have an easier solution, but if you
can't find that solution, there will be a slower way, at the cost of throughput.
Set a par for each goal based on knowing those solutions; it's definitely possible
for someone to come in under par.
