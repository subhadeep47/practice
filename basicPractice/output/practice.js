let user = 'rohan';
//array
var user1 = ['1', '2'];
var user2 = [1, 2];
//tupple, order should be maintained
var temp = [1, '1'];
var temp1 = ['1', false];
//object, ? means optional
var obj = { name: 'rohan' }; //when we know all the keys in object
var obj1 = {}; //when we dont know all the keys and types beforehand
obj1.name = 'null';
console.log(user);
//to use octal, binary, hexa we need to add some prefix before the number
var oct = 0o100001;
var bin = 0b0101010;
var hexa = 0x00001;
console.log(10 + oct);
var abcd = 'a';
function oddEven(value) {
    let oddEven = value % 2 == 0;
    return {
        number: value,
        oddEven
    };
}
oddEven(200);
let std = {
    name: 'Rohan',
    age: 27,
    stream: 'SCI'
};
export {};
