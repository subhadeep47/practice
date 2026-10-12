import type { Student } from "./practice.js";

let std:Student = {
    name: 'Rohan',
    age: 27,
    stream: 'SCI'
}

//default value of enums are 0,1,2....
export enum who {
    STUDENT='student',
    TEACHER='teacher',
    FACULTY='faculty'
}

let std1: Student = {
    name: 'Rahul',
    age: 18,
    stream: 'ARTS',
    who: who.STUDENT
}

console.log(std1);

class Product {
    name:string;
    price:number;
    isCartEmpty:boolean = true

    constructor(name:string, price:number){
        this.name = name;
        this.price = price;
    }

    buyProduct():void {
        if(this.isCartEmpty){
            console.log('No product available');            
        }
        else{
            console.log(`product ${this.name} ordered!`);            
        }
    }

    addToCart():void {
        this.isCartEmpty = false;
    }
}

let product1:Product = new Product('TV', 5000);

product1.addToCart();
product1.buyProduct();
