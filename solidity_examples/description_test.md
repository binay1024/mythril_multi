## Description about test file

* test1.sol   
Contract A가 Contract B를 호출하고 값을 받음.  

* test2.sol  
Contract A는 Contract B의 함수를 호출하고 인자를 전달.  

* test3.sol  
Contract A는 Contract B의 상태를 수정하는 Contract B의 함수를 호출.  

* test4.sol  
Contract A는 Contract B에서 이벤트를 발생시키는 함수를 호출.  

* ContractA.sol  
Contract A는 ContractB.sol을 import를 하여 생성자에서 이미 deployed된 contractB의 주소를 인자로 넣어 Contract B의 함수를 호출.

* ContractB.sol  
Contract B는 전역변수 value를 설정하는 setter 함수가 존재.

* ContractC.sol  
Contract A는 ContractB.sol을 import를 하여 생성자에서 new로 객체를 생성하고 Contract B의 함수를 호출.

* ContractD.sol  
Contract A는 ContractB.sol을 import를 하여 생성자에서 create로 객체를 생성하고 Contract B의 함수를 호출.

* ContractE.sol  
Contract A는 ContractB.sol을 import를 하여 생성자에서 create2로 객체를 생성하고 Contract B의 함수를 호출.

* inheritance.sol  
Contract A가 Contract B를 상속받아서 Contract B의 값을 변환.

