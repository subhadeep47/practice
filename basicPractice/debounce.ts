export function debounce<T extends (...args: any[]) => void>(
    callback: T, 
    delay: number
): (...args: Parameters<T>) => void {
    let timerId: ReturnType<typeof setTimeout> | undefined;

    return function (...args: Parameters<T>): void {
        if(timerId !== undefined){
            clearTimeout(timerId);
        }

        timerId = setTimeout(() => {
            callback(...args);
        }, delay);
    };
};

function debounceTask(searchText: String): void {
    console.log(`searching the text ${searchText} now after user completed the type`);
}

const debouncedSearch = debounce(debounceTask, 500);

const searchInput = document.getElementById("searchInput") as HTMLInputElement;

searchInput.addEventListener("input", (event) => {
    const target = event.target as HTMLInputElement;
    debouncedSearch(target.value);
});