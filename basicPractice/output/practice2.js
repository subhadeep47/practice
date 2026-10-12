let std = {
    name: 'Rohan',
    age: 27,
    stream: 'SCI'
};
//default value of enums are 0,1,2....
export var who;
(function (who) {
    who["STUDENT"] = "student";
    who["TEACHER"] = "teacher";
    who["FACULTY"] = "faculty";
})(who || (who = {}));
let std1 = {
    name: 'Rahul',
    age: 18,
    stream: 'ARTS',
    who: who.STUDENT
};
console.log(std1);
class Product {
    name;
    price;
    isCartEmpty = true;
    constructor(name, price) {
        this.name = name;
        this.price = price;
    }
    buyProduct() {
        if (this.isCartEmpty) {
            console.log('No product available');
        }
        else {
            console.log(`product ${this.name} ordered!`);
        }
    }
    addToCart() {
        this.isCartEmpty = false;
    }
}
let product1 = new Product('TV', 5000);
product1.addToCart();
product1.buyProduct();
