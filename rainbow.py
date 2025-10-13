# Ultra-simplified example of rainbow tables
import hashlib
import re
import time

# For this example, assume that a password is a single plain word.
with open("/usr/share/dict/words") as f:
	words = [w for w in f.read().split() if re.match("^[a-z]+$", w)]

# Turn a password into its hash - this needs to match the system being attacked
def make_hash(password):
	time.sleep(0.125) # Pretend that it's actually costly to do this
	return hashlib.sha256(password.encode()).hexdigest()

# Turn a hash into another password to guess. This can be completely arbitrary,
# but the efficiency of the rainbow table depends on how plausible this new
# guess is.
def make_password(hash):
	return words[int(hash, 16) % len(words)]

# The chain length is a tradeoff between storage efficiency and computation
# efficiency. Each row in the rainbow table will be able to decrypt this many
# hashes into their original words.
CHAIN_LENGTH = 16

# Build up a rainbow table. This can be fully precomputed and saved, eg into a
# database. The only part that needs to be saved is the mapping from final hash
# to seed word.
table = {}
def rainbow(seed):
	word = seed
	for _ in range(CHAIN_LENGTH):
		hash = make_hash(word)
		word = make_password(hash)
		# print(word) # Get a quick dump of the attackable words, for demo purposes
	table[make_hash(word)] = seed

# Build up a rainbow table using a few seed words. It doesn't matter what these
# are, but the rainbow table will be able to decrypt all and only what comes up
# in each of these chains.
rainbow("password")
rainbow("secret")
rainbow("hello")
rainbow("world")
print(table)
# At this point, we could save the rainbow table to a file or database, and
# reuse it for every hash we want to attack.

# To attack a hash, we start by following its chain until we find something in
# our rainbow table, or we've done as many steps as we otherwise would.
def attack(target):
	guess = target
	print("Attacking", target, "...")
	for _ in range(CHAIN_LENGTH):
		if guess in table:
			break
		word = make_password(guess)
		guess = make_hash(word)
	else:
		print("Not found, can't solve")
		return
	# If we followed this hash's chain and found something in our table, that
	# means that the password MUST BE found in that chain. Follow the chain
	# from the start until we reach that point. Note that the number of steps
	# in the first loop plus the number of steps in this second loop will
	# always be the chain length, so we could actually count that off and stop
	# by position if we prefer.
	word = table[guess]
	for _ in range(CHAIN_LENGTH):
		hash = make_hash(word)
		if hash == target:
			print("FOUND PASSWORD:", word)
			return
		word = make_password(hash)

attack('9b5357c3d652b8c9e785424a1be13ae5be222446db77179fadc57b7c98b338eb')
attack('7726c1a3f862854a8e517fa31abf8b31a3ec1e51970e809156aea7e02495ac07')
attack('63069b47c2cd11c489be8d37493c04bc018879c7bf372420ae8226fce82019ba')
attack('986a1b7135f4986150aa5fa0028feeaa66cdaf3ed6a00a355dd86e042f7fb494')

# So, don't store unsalted password hashes. Even if you're using something much more
# secure than plain SHA256, unsalted hashes are inherently vulnerable, and even if
# your passwords are peppered, that just means an attacker needs to use the right
# pepper, which isn't nearly secure enough. Unique salt for every password means the
# rainbow table has virtually no value.
