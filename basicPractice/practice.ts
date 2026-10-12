import { who } from "./practice2.js";

let user:string='rohan';

//array
var user1:Array<string> = ['1', '2'];
var user2:ReadonlyArray<number> = [1,2];

//tupple, order should be maintained
var temp:[number, string] = [1, '1'];
var temp1:readonly[string, boolean] = ['1', false];

//object, ? means optional
var obj:{name: string, age?:number} = {name: 'rohan'}; //when we know all the keys in object
var obj1:{
    name?: string,
    [key:string]:string|number|boolean
}={}; //when we dont know all the keys and types beforehand

obj1.name = 'null';

console.log(user);

//to use octal, binary, hexa we need to add some prefix before the number
var oct:number=0o100001;
var bin:number=0b0101010;
var hexa:number=0x00001;

console.log(10+oct);

//literals
type myType = 'a' | 'b';
var abcd:myType = 'a';

function oddEven(value:number):object {
    let oddEven = value%2 == 0;
    return {
        number: value,
        oddEven
    };
}

oddEven(200);

interface BasicInfo {
    name: string,
    age: number,
    who?: who
}

export interface Student extends BasicInfo {
    stream: string
}

let std: Student = {
    name: 'Rohan',
    age: 27,
    stream: 'SCI',
    who: who.STUDENT
}