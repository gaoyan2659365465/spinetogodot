// Smooth scrolling for navigation links
document.querySelectorAll('nav a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    });
});

// Add animation on scroll
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.classList.add('animate');
        }
    });
}, observerOptions);

// Observe feature items
document.querySelectorAll('.feature-item').forEach(item => {
    observer.observe(item);
});

// Download button click tracking
document.querySelectorAll('.btn-secondary').forEach(btn => {
    btn.addEventListener('click', function() {
        // You can add analytics tracking here
        console.log('Download clicked:', this.textContent);
    });
});

// Responsive navigation
const navToggle = document.createElement('button');
navToggle.textContent = '☰';
navToggle.className = 'nav-toggle';
navToggle.style.display = 'none';

document.querySelector('nav .container').prepend(navToggle);

navToggle.addEventListener('click', () => {
    document.querySelector('nav ul').classList.toggle('nav-open');
});

// Show/hide nav toggle on mobile
function checkScreenSize() {
    if (window.innerWidth <= 768) {
        navToggle.style.display = 'block';
        document.querySelector('nav ul').classList.add('nav-mobile');
    } else {
        navToggle.style.display = 'none';
        document.querySelector('nav ul').classList.remove('nav-open', 'nav-mobile');
    }
}

window.addEventListener('resize', checkScreenSize);
checkScreenSize();