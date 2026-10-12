//Partial is utility type when we dont know if all keys will be available or not
let value = {
    name: 'Rahul',
    age: 29,
};
console.log(value);
//Required will force to add all keys even if its marked as optional with '?'
function getValue(data) {
    console.log(data);
}
getValue({ name: 'rohan', age: 27, address: { city: 'barasat', zip: '700124' } });
export {};
