// Shared utilities for Document Archive
const DocumentArchive = {
    // Use the root path from Rails engine config, falling back to empty string for root mount
    ROOT_PATH: (window.DocumentArchiveConfig && window.DocumentArchiveConfig.rootPath) || '',

    get API_BASE_URL() {
        return this.ROOT_PATH;
    },

    // Load and display stats in the stats bar
    async loadStats(format = 'full') {
        try {
            const response = await fetch(`${this.API_BASE_URL}/api/stats`);
            const stats = await response.json();
            const statsEl = document.getElementById('stats');
            if (statsEl) {
                if (format === 'articles') {
                    statsEl.textContent = `${stats.articles} articles in ${stats.documents} documents`;
                } else if (format === 'documents') {
                    statsEl.textContent = `${stats.documents} documents containing ${stats.articles} articles`;
                } else {
                    statsEl.textContent = `${stats.articles} articles • ${stats.documents} documents • ${stats.embeddings} embeddings`;
                }
            }
            return stats;
        } catch (error) {
            console.error('Error loading stats:', error);
            const statsEl = document.getElementById('stats');
            if (statsEl) {
                statsEl.textContent = 'Unable to load statistics';
            }
            return null;
        }
    },

    // Create an article card element
    createArticleCard(article, options = {}) {
        const { showSimilarity = false, highlightType = null, highlightQuery = null } = options;

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

        // Document info with name and format links
        const docInfo = document.createElement('div');
        docInfo.className = 'article-doc-info';

        const docName = article.documentName || 'Unknown Document';
        const hasFormats = article.pdfUrl || article.txtUrl || article.markdownUrl;

        if (hasFormats) {
            const docLabel = document.createElement('span');
            docLabel.className = 'doc-label';
            docLabel.textContent = docName;
            docInfo.appendChild(docLabel);

            const formatLinks = document.createElement('span');
            formatLinks.className = 'format-links';

            if (article.pdfUrl) {
                const pdfLink = document.createElement('a');
                pdfLink.href = article.pdfUrl;
                pdfLink.target = '_blank';
                pdfLink.rel = 'noopener';
                pdfLink.className = 'format-link format-pdf';
                pdfLink.textContent = 'PDF';
                pdfLink.title = 'Open PDF in new window';
                formatLinks.appendChild(pdfLink);
            }

            if (article.txtUrl) {
                const txtLink = document.createElement('a');
                txtLink.href = article.txtUrl;
                txtLink.target = '_blank';
                txtLink.rel = 'noopener';
                txtLink.className = 'format-link format-txt';
                txtLink.textContent = 'TXT';
                txtLink.title = 'Open text file in new window';
                formatLinks.appendChild(txtLink);
            }

            if (article.markdownUrl) {
                const mdLink = document.createElement('a');
                mdLink.href = `${this.ROOT_PATH}/documents/${article.documentId}/markdown`;
                mdLink.className = 'format-link format-md';
                mdLink.textContent = 'MD';
                mdLink.title = 'View markdown';
                formatLinks.appendChild(mdLink);
            }

            docInfo.appendChild(formatLinks);
        } else {
            docInfo.textContent = docName;
        }

        titleDiv.appendChild(docInfo);

        const meta = document.createElement('div');
        meta.className = 'article-meta';
        meta.innerHTML = `
            <span><strong>ID:</strong> ${article.id}</span>
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
        if (highlightType === 'summary' && highlightQuery) {
            summary.innerHTML = this.highlightMatches(article.summary, highlightQuery);
        } else {
            summary.textContent = article.summary;
        }
        card.appendChild(summary);

        const tags = document.createElement('div');
        tags.className = 'article-tags';

        if (article.categories && article.categories.length > 0) {
            article.categories.forEach(cat => {
                const tag = document.createElement('a');
                tag.className = 'tag category tag-link';
                tag.href = `${this.ROOT_PATH}/articles?category=${encodeURIComponent(cat)}`;
                tag.title = `View all articles in category: ${cat}`;
                if (highlightType === 'categories' && highlightQuery) {
                    tag.innerHTML = this.highlightMatches(cat, highlightQuery);
                } else {
                    tag.textContent = cat;
                }
                tags.appendChild(tag);
            });
        }

        if (article.keywords && article.keywords.length > 0) {
            article.keywords.slice(0, 5).forEach(keyword => {
                const tag = document.createElement('a');
                tag.className = 'tag keyword tag-link';
                tag.href = `${this.ROOT_PATH}/articles?keyword=${encodeURIComponent(keyword)}`;
                tag.title = `View all articles with keyword: ${keyword}`;
                if (highlightType === 'keywords' && highlightQuery) {
                    tag.innerHTML = this.highlightMatches(keyword, highlightQuery);
                } else {
                    tag.textContent = keyword;
                }
                tags.appendChild(tag);
            });
        }

        card.appendChild(tags);
        return card;
    },

    // Create a document card element
    createDocumentCard(doc, options = {}) {
        const { linkToDetail = false } = options;

        const card = document.createElement('div');
        card.className = 'article-card document-card';
        if (linkToDetail) {
            card.style.cursor = 'pointer';
            card.addEventListener('click', () => {
                window.location.href = `${this.ROOT_PATH}/documents/${doc.id}`;
            });
        }

        const header = document.createElement('div');
        header.className = 'article-header';

        const titleDiv = document.createElement('div');
        titleDiv.style.flex = '1';

        const title = document.createElement('div');
        title.className = 'article-title';
        title.textContent = doc.name || 'Untitled Document';
        titleDiv.appendChild(title);

        const meta = document.createElement('div');
        meta.className = 'article-meta';
        const pubDateDisplay = doc.publicationDate
            ? new Date(doc.publicationDate).toLocaleDateString()
            : 'Unknown';
        meta.innerHTML = `
            <span><strong>ID:</strong> ${doc.id}</span>
            <span><strong>Published:</strong> ${pubDateDisplay}</span>
        `;
        titleDiv.appendChild(meta);

        header.appendChild(titleDiv);

        const articleCount = document.createElement('div');
        articleCount.className = 'article-count-badge';
        articleCount.textContent = `${doc.articleCount} article${doc.articleCount !== 1 ? 's' : ''}`;
        header.appendChild(articleCount);

        card.appendChild(header);
        return card;
    },

    // Highlight search matches in text
    highlightMatches(text, query) {
        if (!text || !query) return text || '';
        const terms = query.toLowerCase().split(/\s+/);
        let result = text;
        terms.forEach(term => {
            const regex = new RegExp(`(${this.escapeRegex(term)})`, 'gi');
            result = result.replace(regex, '<mark>$1</mark>');
        });
        return result;
    },

    // Escape special regex characters
    escapeRegex(string) {
        return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    },

    // Display articles in a container
    displayArticles(container, articles, options = {}) {
        container.innerHTML = '';
        if (articles.length === 0) {
            container.innerHTML = '<p class="no-results">No articles found.</p>';
        } else {
            articles.forEach(article => {
                container.appendChild(this.createArticleCard(article, options));
            });
        }
    },

    // Display documents in a container
    displayDocuments(container, documents, options = {}) {
        container.innerHTML = '';
        if (documents.length === 0) {
            container.innerHTML = '<p class="no-results">No documents found.</p>';
        } else {
            documents.forEach(doc => {
                container.appendChild(this.createDocumentCard(doc, options));
            });
        }
    },

    // Update pagination controls
    updatePagination(options) {
        const { currentPage, totalItems, itemsPerPage, pageInfoId, prevButtonId, nextButtonId } = options;
        const totalPages = Math.ceil(totalItems / itemsPerPage);
        const pageInfo = document.getElementById(pageInfoId);
        const prevButton = document.getElementById(prevButtonId);
        const nextButton = document.getElementById(nextButtonId);

        if (pageInfo) pageInfo.textContent = `Page ${currentPage + 1} of ${totalPages}`;
        if (prevButton) prevButton.disabled = currentPage === 0;
        if (nextButton) nextButton.disabled = currentPage >= totalPages - 1;
    }
};
