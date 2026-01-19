// Search pagination state
let currentQuery = '';
let searchLimit = 10;
const searchState = {
    keywords: { page: 0, total: 0 },
    categories: { page: 0, total: 0 },
    summary: { page: 0, total: 0 }
};

// Initialize the app
document.addEventListener('DOMContentLoaded', () => {
    DocumentArchive.loadStats('full');
    setupEventListeners();
});

function setupEventListeners() {
    document.getElementById('searchButton').addEventListener('click', performSearch);
    document.getElementById('searchInput').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') performSearch();
    });

    // Keywords pagination
    document.getElementById('keywordsPrevButton').addEventListener('click', () => {
        if (searchState.keywords.page > 0) {
            searchState.keywords.page--;
            loadKeywordsResults();
        }
    });
    document.getElementById('keywordsNextButton').addEventListener('click', () => {
        searchState.keywords.page++;
        loadKeywordsResults();
    });

    // Categories pagination
    document.getElementById('categoriesPrevButton').addEventListener('click', () => {
        if (searchState.categories.page > 0) {
            searchState.categories.page--;
            loadCategoriesResults();
        }
    });
    document.getElementById('categoriesNextButton').addEventListener('click', () => {
        searchState.categories.page++;
        loadCategoriesResults();
    });

    // Summary pagination
    document.getElementById('summaryPrevButton').addEventListener('click', () => {
        if (searchState.summary.page > 0) {
            searchState.summary.page--;
            loadSummaryResults();
        }
    });
    document.getElementById('summaryNextButton').addEventListener('click', () => {
        searchState.summary.page++;
        loadSummaryResults();
    });
}

async function performSearch() {
    const query = document.getElementById('searchInput').value.trim();
    if (!query) {
        alert('Please enter a search query');
        return;
    }

    currentQuery = query;
    searchLimit = parseInt(document.getElementById('limitSelect').value);

    // Reset pagination state
    searchState.keywords.page = 0;
    searchState.categories.page = 0;
    searchState.summary.page = 0;

    // Show loading indicator
    document.getElementById('loadingIndicator').classList.remove('hidden');
    document.getElementById('semanticResultsContainer').classList.add('hidden');
    document.getElementById('textSearchResultsContainer').classList.add('hidden');

    try {
        // Perform all searches in parallel
        const [semanticResults, keywordsResults, categoriesResults, summaryResults] = await Promise.all([
            performSemanticSearch(query, searchLimit),
            performKeywordsSearch(query, searchLimit, 0),
            performCategoriesSearch(query, searchLimit, 0),
            performSummarySearch(query, searchLimit, 0)
        ]);

        // Update state
        searchState.keywords.total = keywordsResults.total;
        searchState.categories.total = categoriesResults.total;
        searchState.summary.total = summaryResults.total;

        // Display results
        displaySemanticResults(semanticResults);
        displayKeywordsResults(keywordsResults.results);
        displayCategoriesResults(categoriesResults.results);
        displaySummaryResults(summaryResults.results);

        // Update pagination
        updateSearchPagination('keywords');
        updateSearchPagination('categories');
        updateSearchPagination('summary');

        // Show containers and hide browse prompt
        document.getElementById('loadingIndicator').classList.add('hidden');
        document.getElementById('semanticResultsContainer').classList.remove('hidden');
        document.getElementById('textSearchResultsContainer').classList.remove('hidden');
        document.getElementById('browsePrompt').classList.add('hidden');

    } catch (error) {
        console.error('Error performing search:', error);
        document.getElementById('loadingIndicator').classList.add('hidden');
        alert('Search error:\n\n' + error.message);
    }
}

async function performSemanticSearch(query, limit) {
    const response = await fetch(`${DocumentArchive.API_BASE_URL}/api/search-text`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query, limit })
    });

    const data = await response.json();
    if (!response.ok) {
        throw new Error(data.error || 'Semantic search failed');
    }
    return data.results;
}

async function performKeywordsSearch(query, limit, offset) {
    const response = await fetch(`${DocumentArchive.API_BASE_URL}/api/search-keywords`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query, limit, offset })
    });

    const data = await response.json();
    if (!response.ok) {
        throw new Error(data.error || 'Keywords search failed');
    }
    return data;
}

async function performCategoriesSearch(query, limit, offset) {
    const response = await fetch(`${DocumentArchive.API_BASE_URL}/api/search-categories`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query, limit, offset })
    });

    const data = await response.json();
    if (!response.ok) {
        throw new Error(data.error || 'Categories search failed');
    }
    return data;
}

async function performSummarySearch(query, limit, offset) {
    const response = await fetch(`${DocumentArchive.API_BASE_URL}/api/search-summary`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query, limit, offset })
    });

    const data = await response.json();
    if (!response.ok) {
        throw new Error(data.error || 'Summary search failed');
    }
    return data;
}

async function loadKeywordsResults() {
    try {
        const data = await performKeywordsSearch(
            currentQuery,
            searchLimit,
            searchState.keywords.page * searchLimit
        );
        searchState.keywords.total = data.total;
        displayKeywordsResults(data.results);
        updateSearchPagination('keywords');
    } catch (error) {
        console.error('Error loading keywords results:', error);
    }
}

async function loadCategoriesResults() {
    try {
        const data = await performCategoriesSearch(
            currentQuery,
            searchLimit,
            searchState.categories.page * searchLimit
        );
        searchState.categories.total = data.total;
        displayCategoriesResults(data.results);
        updateSearchPagination('categories');
    } catch (error) {
        console.error('Error loading categories results:', error);
    }
}

async function loadSummaryResults() {
    try {
        const data = await performSummarySearch(
            currentQuery,
            searchLimit,
            searchState.summary.page * searchLimit
        );
        searchState.summary.total = data.total;
        displaySummaryResults(data.results);
        updateSearchPagination('summary');
    } catch (error) {
        console.error('Error loading summary results:', error);
    }
}

function displaySemanticResults(results) {
    const container = document.getElementById('semanticResults');
    const resultCount = document.getElementById('semanticResultCount');

    container.innerHTML = '';
    resultCount.textContent = results.length;

    if (results.length === 0) {
        container.innerHTML = '<p class="no-results">No semantic matches found.</p>';
    } else {
        results.forEach(article => {
            container.appendChild(DocumentArchive.createArticleCard(article, { showSimilarity: true }));
        });
    }
}

function displayKeywordsResults(results) {
    const container = document.getElementById('keywordsResults');
    const resultCount = document.getElementById('keywordsResultCount');

    container.innerHTML = '';
    resultCount.textContent = searchState.keywords.total;

    if (results.length === 0) {
        container.innerHTML = '<p class="no-results">No keyword matches found.</p>';
    } else {
        results.forEach(article => {
            container.appendChild(DocumentArchive.createArticleCard(article, {
                highlightType: 'keywords',
                highlightQuery: currentQuery
            }));
        });
    }
}

function displayCategoriesResults(results) {
    const container = document.getElementById('categoriesResults');
    const resultCount = document.getElementById('categoriesResultCount');

    container.innerHTML = '';
    resultCount.textContent = searchState.categories.total;

    if (results.length === 0) {
        container.innerHTML = '<p class="no-results">No category matches found.</p>';
    } else {
        results.forEach(article => {
            container.appendChild(DocumentArchive.createArticleCard(article, {
                highlightType: 'categories',
                highlightQuery: currentQuery
            }));
        });
    }
}

function displaySummaryResults(results) {
    const container = document.getElementById('summaryResults');
    const resultCount = document.getElementById('summaryResultCount');

    container.innerHTML = '';
    resultCount.textContent = searchState.summary.total;

    if (results.length === 0) {
        container.innerHTML = '<p class="no-results">No summary matches found.</p>';
    } else {
        results.forEach(article => {
            container.appendChild(DocumentArchive.createArticleCard(article, {
                highlightType: 'summary',
                highlightQuery: currentQuery
            }));
        });
    }
}

function updateSearchPagination(type) {
    const state = searchState[type];
    const totalPages = Math.ceil(state.total / searchLimit);
    const pageInfo = document.getElementById(`${type}PageInfo`);
    const prevButton = document.getElementById(`${type}PrevButton`);
    const nextButton = document.getElementById(`${type}NextButton`);
    const pagination = document.getElementById(`${type}Pagination`);

    if (state.total === 0) {
        pagination.classList.add('hidden');
        return;
    }

    pagination.classList.remove('hidden');
    pageInfo.textContent = `Page ${state.page + 1} of ${totalPages}`;
    prevButton.disabled = state.page === 0;
    nextButton.disabled = state.page >= totalPages - 1;
}
