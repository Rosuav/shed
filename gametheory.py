"""Game theory analysis: Empowered Rock-Paper-Scissors

The game is as follows:
* Two players, A and B, start with equal life totals.
* Each round, the players each choose one throw to Empower, one to Weaken.
* Once choices have been made, they are revealed to both players.
* The two players then throw Rock, Paper, or Scissors three times. Winners
  are determined by the usual rules (paper > rock > scissors > paper).
* If the throws are the same, zero damage is dealt
* If the throws are different, the loser is hit for 1 HP...
  - doubled if the winning throw was Empowered...
  - and doubled (independently) if the losing throw was Weakened.
  - This can stack, resulting in 4 HP damage.
* The game ends as soon as one player is out of HP.

Against players, this would get very psychological. But is there any sort
of mathematical strategy to employ?
"""

"""Analysis.

There are 81 possible game states as the Empowers and Weakens are independent.
However, they are rotationally symmetrical, so any one of the four can be fixed
in place and the others considered relative to it. Thus there are 27 relevant
states. For this analysis we will assume that player A Empowers Rock, aka AER.

Player A can choose to Weaken any of the three throws - the same as empowered,
the one that defeats the empowered, and the one that loses to the empowered.
Player B has the same choices, plus a random selection of which to empower.
Then, for each of the 27 possible game states, there are 6 possible throws to
consider (since a 'push' never deals any damage - though, secondary question,
how would this analysis change if a push dealt both damages?).
"""

# Internally we use a cryptic short form; for display, a longer form of the same info.
game_states = {
	AE+AW+BE+BW: f"AE{AE}-AW{AW}-BE{BE}-BW{BW}"
	for AE in "R" # Simplify: game states are rotationally symmetric
	for AW in "RPS"
	for BE in "RPS"
	for BW in "RPS"
}
# If A throws Rock and B throws Paper, winner["R" + "P"] shows the winner to be "B".
winner = {
	"RP": "B", "PR": "A",
	"RS": "A", "SR": "B",
	"PS": "B", "SP": "A",
}
print("State", "A throw", "B throws...", "Net", sep="\t")
for state in game_states:
	AE, AW, BE, BW = state
	for AT in "RPS":
		print(state + "\t" + AT, end="\t")
		score = 0
		for BT in "RPS":
			if AT == BT: continue
			if winner[AT + BT] == "B":
				dmg = -1
				if BT == BE: dmg *= 2
				if AT == AW: dmg *= 2
			else:
				dmg = 1
				if AT == AE: dmg *= 2
				if BT == BW: dmg *= 2
			print(BT, dmg, end="\t")
			score += dmg
			totscore += dmg
		print("=", score)
"""
Based on these possible payoffs, given each possible game state, each
player has an expected payoff for a throw, assuming a random selection
from the opponent. This should then update each player's desire to do
each throw. But I'm not sure exactly how to math that part out.
"""
