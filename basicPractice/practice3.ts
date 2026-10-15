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

// Extracting the inner resolved value of a Promise
type UnwrappedPromise<T> = T extends Promise<infer U> ? U : T;

type ResponseData = UnwrappedPromise<Promise<{ id: string }>>;

async function random() {
    let response: ResponseData = await Promise.resolve({id: "user123"});   
}

// Extracts the return type of a given function type
type GetReturnType<T> = T extends (...args: any[]) => infer R ? R : never;

const getLength = () => 42;
type ReturnOfLength = GetReturnType<typeof getLength>;

//
type Config = Record<string, string | number>;

// Using 'satisfies' keeps the specific value type intact
const palette = {
  primary: "#ff0000",
  accent: 123
} satisfies Config;

// Safe to invoke string methods because TS knows 'primary' is string literal, not 'string | number'
palette.primary.toUpperCase(); 
