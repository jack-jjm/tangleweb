STATE:
- Waiting for input
  - on click, ---> MOVE(start node, end node, edge)
- Moving player (start node, end node, edge)
  - substate: progress (0 to 1)
  - when progress > 0.5, check if we should die
     - ---> DIE
  - 
- Just died
  - Wait for animation to be done, then play game over screen
- On game over screen
  - Wait for key to reset game
- Won
  - Wait for key to start new game


A state:
  - Can be transitioned to with parameters
  - Has substate
  - Has an initializer function
  - Has an update function

LOOP:

- Run update for current state
- if TRANSITION is set, run initializer code and set state to transition state