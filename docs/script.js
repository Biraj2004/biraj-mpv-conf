/**
 * ==========================================================================
 * Biraj MPV Configuration - Documentation Scripts
 * Dynamic, maintainable, vanilla ES6+ logic with zero dependencies.
 * ==========================================================================
 */

'use strict';

document.addEventListener('DOMContentLoaded', () => {
    initDynamicYear();
    initMobileNavigation();
    initOsTabs();
    initShortcutsFiltering();
    initLightboxModal();
    initScrollSpy();
});

/**
 * 1. Dynamic Year in Footer
 */
function initDynamicYear() {
    const yearEl = document.getElementById('currentYear');
    if (yearEl) {
        yearEl.textContent = new Date().getFullYear();
    }
}

/**
 * 2. Mobile Navigation Drawer Toggle
 */
function initMobileNavigation() {
    const mobileToggle = document.getElementById('mobileToggle');
    const navLinks = document.getElementById('navLinks');

    if (!mobileToggle || !navLinks) return;

    mobileToggle.addEventListener('click', () => {
        navLinks.classList.toggle('open');
    });

    // Close menu when clicking any nav link
    navLinks.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', () => {
            navLinks.classList.remove('open');
        });
    });
}

/**
 * 3. Operating System Installation Tab Switcher
 */
function initOsTabs() {
    const osTabButtons = document.querySelectorAll('.os-tab-btn');
    const osContents = document.querySelectorAll('.os-content');

    if (!osTabButtons.length || !osContents.length) return;

    osTabButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const targetOs = btn.getAttribute('data-os');

            // Toggle active state on buttons
            osTabButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            // Toggle active state on content panels
            osContents.forEach(panel => {
                if (panel.id === `content-${targetOs}`) {
                    panel.classList.add('active');
                } else {
                    panel.classList.remove('active');
                }
            });
        });
    });
}

/**
 * 4. Interactive Shortcuts Table Search & Category Filter
 */
function initShortcutsFiltering() {
    const searchInput = document.getElementById('shortcutSearch');
    const table = document.getElementById('shortcutsTable');
    const filterPills = document.querySelectorAll('.filter-pill');

    if (!table) return;

    const rows = table.querySelectorAll('tbody tr');
    let activeCategory = 'all';
    let searchQuery = '';

    function applyFilters() {
        rows.forEach(row => {
            const rowText = row.textContent.toLowerCase();
            const rowCategory = row.getAttribute('data-cat') || '';

            const matchesCategory = (activeCategory === 'all') || (rowCategory === activeCategory);
            const matchesSearch = !searchQuery || rowText.includes(searchQuery);

            if (matchesCategory && matchesSearch) {
                row.style.display = '';
            } else {
                row.style.display = 'none';
            }
        });
    }

    // Text search input listener
    if (searchInput) {
        searchInput.addEventListener('input', (e) => {
            searchQuery = e.target.value.toLowerCase().trim();
            applyFilters();
        });
    }

    // Category pills filter listener
    if (filterPills.length) {
        filterPills.forEach(pill => {
            pill.addEventListener('click', () => {
                filterPills.forEach(p => p.classList.remove('active'));
                pill.classList.add('active');
                activeCategory = pill.getAttribute('data-category') || 'all';
                applyFilters();
            });
        });
    }
}

/**
 * 5. Fullscreen Image Lightbox Modal
 */
function initLightboxModal() {
    const modal = document.getElementById('lightboxModal');
    const img = document.getElementById('lightboxImg');
    const caption = document.getElementById('lightboxCaption');
    const closeBtn = document.getElementById('lightboxClose');
    const backdrop = document.getElementById('lightboxBackdrop');

    if (!modal || !img) return;

    function openModal(src, titleText) {
        img.src = src;
        if (caption) caption.textContent = titleText || '';
        modal.classList.add('active');
        modal.setAttribute('aria-hidden', 'false');
        document.body.style.overflow = 'hidden';
    }

    function closeModal() {
        modal.classList.remove('active');
        modal.setAttribute('aria-hidden', 'true');
        document.body.style.overflow = '';
    }

    // Gallery cards zoom trigger
    document.querySelectorAll('.zoomable-trigger').forEach(card => {
        card.addEventListener('click', () => {
            const src = card.getAttribute('data-img');
            const title = card.querySelector('.gallery-title')?.textContent || '';
            openModal(src, title);
        });
    });

    // Hero preview image zoom trigger
    const heroImg = document.querySelector('.hero-image');
    if (heroImg) {
        heroImg.addEventListener('click', () => {
            openModal(heroImg.src, 'ModernZ Fluent OSC Interface & Seekbar Thumbnails');
        });
    }

    if (closeBtn) closeBtn.addEventListener('click', closeModal);
    if (backdrop) backdrop.addEventListener('click', closeModal);

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && modal.classList.contains('active')) {
            closeModal();
        }
    });
}

/**
 * 6. Dynamic ScrollSpy Navigation Indicator
 */
function initScrollSpy() {
    const sections = document.querySelectorAll('section[id]');
    const navLinks = document.querySelectorAll('.nav-link');
    const header = document.getElementById('header');

    if (!sections.length || !navLinks.length) return;

    window.addEventListener('scroll', () => {
        const scrollY = window.scrollY;

        // Navbar shadow elevation
        if (header) {
            if (scrollY > 20) {
                header.style.boxShadow = '0 8px 24px rgba(0, 0, 0, 0.4)';
            } else {
                header.style.boxShadow = 'none';
            }
        }

        // Active link tracking
        sections.forEach(sec => {
            const top = sec.offsetTop - 120;
            const height = sec.offsetHeight;
            const id = sec.getAttribute('id');

            if (scrollY >= top && scrollY < top + height) {
                navLinks.forEach(link => {
                    link.classList.remove('active');
                    if (link.getAttribute('href') === `#${id}`) {
                        link.classList.add('active');
                    }
                });
            }
        });
    }, { passive: true });
}

/**
 * Global Copy-to-Clipboard Helper
 * @param {string} elementId - Target code element ID
 * @param {HTMLElement} btn - The clicked button element
 */
function copyCode(elementId, btn) {
    const target = document.getElementById(elementId);
    if (!target) return;

    const text = target.innerText || target.textContent;

    navigator.clipboard.writeText(text).then(() => {
        if (btn) {
            btn.classList.add('copied');
            setTimeout(() => {
                btn.classList.remove('copied');
            }, 2000);
        }
    }).catch(err => {
        console.error('Failed to copy to clipboard: ', err);
    });
}
