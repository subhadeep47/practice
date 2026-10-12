export function debounce(callback, delay) {
    let timerId;
    return function (...args) {
        if (timerId !== undefined) {
            clearTimeout(timerId);
            console.log("cleared the time since user is typing fast");
        }
        timerId = setTimeout(() => {
            callback(...args);
        }, delay);
    };
}
;
function debounceTask(searchText) {
    console.log(`searching the text ${searchText} now after user completed the type`);
}
const debouncedSearch = debounce(debounceTask, 500);
const searchInput = document.getElementById("searchInput");
searchInput.addEventListener("input", (event) => {
    const target = event.target;
    debouncedSearch(target.value);
});
