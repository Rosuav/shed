# Spaced repetition algorithm
# Each user has a question::weight mapping. When a question is answered
# correctly, the weight is halved; when incorrectly, it is increased by 1.0.
# The next unasked question is weighted at 1.0, if there is such.
# The most recently asked question is weighted at zero.
# A question is selected at random, based on the weights.
import random
from types import SimpleNamespace
questions = "ABCDEFGHIJKL" # TODO: Have an actual list of viable questions
user_info = SimpleNamespace(username="Rosuav", weights=[], last_question=None)

def get_question(user):
	weight = sum(user.weights)
	# Don't ask the same question twice.
	if user.last_question is not None:
		weight -= user.weights[user.last_question]
	# Have 1.0 chances of asking a new question.
	if len(user.weights) < len(questions): weight += 1.0
	# Pick based on the weighted random values.
	choice = random.random() * weight
	for question, weight in enumerate(user.weights):
		# Ignore the most-recently-asked, which is treated
		# as if its weight were zero.
		if question == user.last_question: continue
		choice -= weight
		if choice <= 0:
			return question
	# If we get here, it's time for a new question.
	# Record that it's been asked, by storing its initial weight,
	# and return its index.
	user.weights.append(1.0)
	return len(user.weights) - 1

def answer_question(user, question, correct):
	if correct: user.weights[question] /= 2
	else: user.weights[question] += 1.0
	user.last_question = question

while True:
	q = get_question(user_info)
	print("Asking:", questions[q])
	correct = input("Right or wrong? ")=="r"
	answer_question(user_info, q, correct)
	print("Weights:", user_info.weights)
