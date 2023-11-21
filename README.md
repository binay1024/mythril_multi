
## Usage

Run:

```
$ python3 myth.py analyze -mc main.bin AttackBridge.bin Sub0.bin Sub1.bin ...
```

```
> python3 myth.py analyze -mc ./solidity_examples/ccs2023/Victim1/Victim1_V10.bin ./solidity_examples/ccs2023/AttackBridge/AttackBridgeV14.bin

Excute 0 TX Loop finish!!!
output the call_chain
++++++++++++++++++++ In 0th open_state ++++++++++++++++++++
    -------- output 0th TX --------
[
['START'], ['EOA', 'None'], ['MAIN', 'constructor'], ['END']]
    -------- output 1th TX --------
[
['START'], ['EOA', 'None'], ['AttackBridge', 'constructor'], ['END']]
    -------- output 2th TX --------
[
['START'], ['EOA', 'None'], ['AttackBridge', 'attack(uint256,bytes)'], ['END'], 
['START'], ['AttackBridge', 'attack(uint256,bytes)'], ['MAIN', 'fallback'], ['END']]
++++++++++++++++++++ In 1th open_state ++++++++++++++++++++
    -------- output 0th TX --------
[
['START'], ['EOA', 'None'], ['MAIN', 'constructor'], ['END']]
    -------- output 1th TX --------
[
['START'], ['EOA', 'None'], ['AttackBridge', 'constructor'], ['END']]
    -------- output 2th TX --------
[
['START'], ['EOA', 'None'], ['AttackBridge', 'attack(uint256,bytes)'], ['END'], 
['START'], ['AttackBridge', 'attack(uint256,bytes)'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'fallback'], ['END']]
++++++++++++++++++++ In 2th open_state ++++++++++++++++++++
    -------- output 0th TX --------
[
['START'], ['EOA', 'None'], ['MAIN', 'constructor'], ['END']]
    -------- output 1th TX --------
[
['START'], ['EOA', 'None'], ['AttackBridge', 'constructor'], ['END']]
    -------- output 2th TX --------
[
['START'], ['EOA', 'None'], ['AttackBridge', 'attack(uint256,bytes)'], ['END'], 
['START'], ['AttackBridge', 'attack(uint256,bytes)'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END']]
++++++++++++++++++++ In 3th open_state ++++++++++++++++++++
    -------- output 0th TX --------
[
['START'], ['EOA', 'None'], ['MAIN', 'constructor'], ['END']]
    -------- output 1th TX --------
[
['START'], ['EOA', 'None'], ['AttackBridge', 'constructor'], ['END']]
    -------- output 2th TX --------
[
['START'], ['EOA', 'None'], ['AttackBridge', 'attack(uint256,bytes)'], ['END'], 
['START'], ['AttackBridge', 'attack(uint256,bytes)'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END']]
Finished symbolic execution


================ Print openstates call_chain ================
print 0th world_state`s call_chain
[
['START'], ['EOA', 'None'], ['AttackBridge', 'attack(uint256,bytes)'], ['END'], 
['START'], ['AttackBridge', 'attack(uint256,bytes)'], ['MAIN', 'fallback'], ['END']]
----------------------------------------------------
print 1th world_state`s call_chain
[
['START'], ['EOA', 'None'], ['AttackBridge', 'attack(uint256,bytes)'], ['END'], 
['START'], ['AttackBridge', 'attack(uint256,bytes)'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'fallback'], ['END']]
----------------------------------------------------
print 2th world_state`s call_chain
[
['START'], ['EOA', 'None'], ['AttackBridge', 'attack(uint256,bytes)'], ['END'], 
['START'], ['AttackBridge', 'attack(uint256,bytes)'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END']]
----------------------------------------------------
print 3th world_state`s call_chain
[
['START'], ['EOA', 'None'], ['AttackBridge', 'attack(uint256,bytes)'], ['END'], 
['START'], ['AttackBridge', 'attack(uint256,bytes)'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END'], 
['START'], ['AttackBridge', 'fallback'], ['MAIN', 'attacked(uint256,address)'], ['END'], 
['START'], ['MAIN', 'attacked(uint256,address)'], ['AttackBridge', 'fallback'], ['END']]
----------------------------------------------------


================ Print openstates call_chain finish ================
print report in [0]th open_state
The analysis was completed successfully. No issues were detected.

print report in [1]th open_state
The analysis was completed successfully. No issues were detected.

print report in [2]th open_state
The analysis was completed successfully. No issues were detected.

print report in [3]th open_state
The analysis was completed successfully. No issues were detected.

time cost [24s]


```

