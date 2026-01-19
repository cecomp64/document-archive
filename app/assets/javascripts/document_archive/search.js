// Configuration
const API_BASE_URL = window.location.origin;

// State
let currentPage = 0;
let totalArticles = 0;
const articlesPerPage = 20;

// Initialize the app
document.addEventListener('DOMContentLoaded', () => {
    loadStats();
    loadArticles(0);
    setupEventListeners();
});

function setupEventListeners() {
    document.getElementById('searchButton').addEventListener('click', performSearch);
    document.getElementById('searchInput').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') performSearch();
    });
    document.getElementById('prevButton').addEventListener('click', () => {
        if (currentPage > 0) {
            currentPage--;
            loadArticles(currentPage * articlesPerPage);
        }
    });
    document.getElementById('nextButton').addEventListener('click', () => {
        currentPage++;
        loadArticles(currentPage * articlesPerPage);
    });
}

async function loadStats() {
    try {
        const response = await fetch(`${API_BASE_URL}/api/stats`);
        const stats = await response.json();
        document.getElementById('stats').textContent =
            `${stats.articles} articles • ${stats.documents} documents • ${stats.embeddings} embeddings`;
    } catch (error) {
        console.error('Error loading stats:', error);
        document.getElementById('stats').textContent = 'Unable to load statistics';
    }
}

async function performSearch() {
    const query = document.getElementById('searchInput').value.trim();
    if (!query) {
        alert('Please enter a search query');
        return;
    }

    const limit = parseInt(document.getElementById('limitSelect').value);

    // Show loading indicator
    document.getElementById('loadingIndicator').classList.remove('hidden');
    document.getElementById('resultsContainer').classList.add('hidden');

    try {
        // Call server-side search endpoint (handles embedding generation)
        const response = await fetch(`${API_BASE_URL}/api/search-text`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                query: query,
                limit: limit
            })
        });

        const data = await response.json();

        if (response.ok) {
            displaySearchResults(data.results);
        } else {
            document.getElementById('loadingIndicator').classList.add('hidden');

            // Show helpful error message
            let errorMsg = data.error || 'Unknown error occurred';
            if (errorMsg.includes('GEMINI_API_KEY')) {
                errorMsg = 'Embedding service not configured.\n\n' +
                          'To enable search:\n' +
                          '1. Set GEMINI_API_KEY environment variable, OR\n' +
                          '2. Install sentence-transformers: pip install sentence-transformers\n' +
                          '   and set EMBEDDING_PROVIDER=sentence-transformers\n\n' +
                          'See README for details.';
            } else if (errorMsg.includes('not installed')) {
                errorMsg = 'Missing package: ' + errorMsg + '\n\n' +
                          'Install with pip and restart the server.';
            }

            alert('Search error:\n\n' + errorMsg);
        }

    } catch (error) {
        console.error('Error performing search:', error);
        document.getElementById('loadingIndicator').classList.add('hidden');
        alert('Network error: Unable to reach the server.\n\n' + error.message);
    }
}

function displaySearchResults(results) {
    const container = document.getElementById('results');
    const resultsContainer = document.getElementById('resultsContainer');
    const resultCount = document.getElementById('resultCount');

    container.innerHTML = '';
    resultCount.textContent = results.length;

    if (results.length === 0) {
        container.innerHTML = '<p>No results found.</p>';
    } else {
        results.forEach(article => {
            container.appendChild(createArticleCard(article, true));
        });
    }

    document.getElementById('loadingIndicator').classList.add('hidden');
    resultsContainer.classList.remove('hidden');
}

async function loadArticles(offset) {
    try {
        const response = await fetch(`${API_BASE_URL}/api/articles?limit=${articlesPerPage}&offset=${offset}`);
        const data = await response.json();

        totalArticles = data.total;
        displayBrowseResults(data.articles);
        updatePagination();
    } catch (error) {
        console.error('Error loading articles:', error);
        document.getElementById('browseResults').innerHTML =
            '<p>Error loading articles. Make sure the API server is running.</p>';
    }
}

function displayBrowseResults(articles) {
    const container = document.getElementById('browseResults');
    container.innerHTML = '';

    if (articles.length === 0) {
        container.innerHTML = '<p>No articles found.</p>';
    } else {
        articles.forEach(article => {
            container.appendChild(createArticleCard(article, false));
        });
    }
}

function createArticleCard(article, showSimilarity) {
    const card = document.createElement('div');
    card.className = 'article-card';

    const header = document.createElement('div');
    header.className = 'article-header';

    const titleDiv = document.createElement('div');
    titleDiv.style.flex = '1';

    const title = document.createElement('div');
    title.className = 'article-title';
    title.textContent = article.title;
    titleDiv.appendChild(title);

    const meta = document.createElement('div');
    meta.className = 'article-meta';
    meta.innerHTML = `
        <span><strong>ID:</strong> ${article.id}</span>
        <span><strong>Document:</strong> ${article.documentId}</span>
        ${article.pageStart ? `<span><strong>Pages:</strong> ${article.pageStart}-${article.pageEnd}</span>` : ''}
    `;
    titleDiv.appendChild(meta);

    header.appendChild(titleDiv);

    if (showSimilarity && article.similarity !== undefined) {
        const similarity = document.createElement('div');
        similarity.className = 'similarity-score';
        similarity.textContent = `${(article.similarity * 100).toFixed(1)}% match`;
        header.appendChild(similarity);
    }

    card.appendChild(header);

    const summary = document.createElement('div');
    summary.className = 'article-summary';
    summary.textContent = article.summary;
    card.appendChild(summary);

    const tags = document.createElement('div');
    tags.className = 'article-tags';

    if (article.categories && article.categories.length > 0) {
        article.categories.forEach(cat => {
            const tag = document.createElement('span');
            tag.className = 'tag category';
            tag.textContent = cat;
            tags.appendChild(tag);
        });
    }

    if (article.keywords && article.keywords.length > 0) {
        article.keywords.slice(0, 5).forEach(keyword => {
            const tag = document.createElement('span');
            tag.className = 'tag keyword';
            tag.textContent = keyword;
            tags.appendChild(tag);
        });
    }

    card.appendChild(tags);
    return card;
}

function updatePagination() {
    const totalPages = Math.ceil(totalArticles / articlesPerPage);
    const pageInfo = document.getElementById('pageInfo');
    const prevButton = document.getElementById('prevButton');
    const nextButton = document.getElementById('nextButton');

    pageInfo.textContent = `Page ${currentPage + 1} of ${totalPages}`;
    prevButton.disabled = currentPage === 0;
    nextButton.disabled = currentPage >= totalPages - 1;
}
