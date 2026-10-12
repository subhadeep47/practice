type ObjectType = {
    name: string,
    age: number,
    address?: {
        city: string,
        zip: string
    }
}

//Partial is utility type when we dont know if all keys will be available or not
let value:Partial<ObjectType> = {
    name:'Rahul',
    age: 29,
}

console.log(value);

//Required will force to add all keys even if its marked as optional with '?'
function getValue(data:Required<ObjectType>):void{
    console.log(data);
}

getValue({name:'rohan', age:27, address:{city:'barasat', zip:'700124'}})

//Pick helps to take only the keys we will specify, & means any one, | means all needed
let value1:Pick<ObjectType, 'name'&'age'> = {
    name: 'abcd',
    age: 19
}

//Omit, Exclude, Extract, NonNullable are also Utility types

type SiteRoles = 'Admin' | 'User' | 'Guest' 

//Record will create keys defined in a literal types
let assignedRoles:Record<SiteRoles, string> = {
    Admin: 'Rohan',
    User: 'Partha',
    Guest: 'ABCD'
}