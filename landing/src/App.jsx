import { useEffect, useRef, useState } from 'react';
import appIcon from '../assets/app-icon.png';
import sourceImage from '../assets/bundled-source.jpg';
import heroDevices from '../assets/hero-devices.png';
import captureScreen from '../screens/capture.png';
import understandScreen from '../screens/understand.png';
import verifyScreen from '../screens/verify.png';
import exportScreen from '../screens/export.png';
import finalPhone from '../assets/final-phone.png';

const REPO_URL = 'https://github.com/adr1el-m/cheezcribe';
const APP_URL = 'https://paperazzi-appcon.vercel.app';

const features = [
  {
    icon: 'scan',
    tone: 'blue',
    title: 'Native OCR',
    copy: 'Read documents on-device with Apple Vision on iOS or bundled ML Kit on Android.',
  },
  {
    icon: 'evidence',
    tone: 'violet',
    title: 'Evidence-linked fields',
    copy: 'Keep extracted values connected to the OCR line and source crop that supports them.',
  },
  {
    icon: 'review',
    tone: 'amber',
    title: 'Focused human review',
    copy: 'Route unsupported, conflicting, or low-quality fields to a clear correction queue.',
  },
  {
    icon: 'spark',
    tone: 'cyan',
    title: 'Optional AI enrichment',
    copy: 'Ask Gemini for document-specific fields only when cloud processing is explicitly enabled.',
  },
  {
    icon: 'drawing',
    tone: 'purple',
    title: 'Drawing reconstruction',
    copy: 'Detect review-required geometry and turn selected plans into editable SVG or DXF.',
  },
  {
    icon: 'export',
    tone: 'green',
    title: 'Useful exports',
    copy: 'Save reviewed records as JSON or CSV, with unresolved values clearly marked.',
  },
];

const steps = [
  {
    number: '01',
    label: 'Capture',
    title: 'Capture the source',
    copy: 'Scan a physical document or import an image or PDF without changing the original.',
    screen: captureScreen,
    alt: 'Paperazzi document capture and on-device processing screen',
    tone: 'blue',
  },
  {
    number: '02',
    label: 'Understand',
    title: 'Extract and interpret',
    copy: 'OCR and optional AI identify text, tables, fields, and engineering drawing elements while preserving source evidence.',
    screen: understandScreen,
    alt: 'Paperazzi document understanding screen with extracted text and drawing regions',
    tone: 'purple',
  },
  {
    number: '03',
    label: 'Verify',
    title: 'Make the human call',
    copy: 'Inspect uncertain values against the source, then confirm, edit, keep the OCR result, or mark it unreadable.',
    screen: verifyScreen,
    alt: 'Paperazzi verification screen with source crop and review controls',
    tone: 'amber',
  },
  {
    number: '04',
    label: 'Export',
    title: 'Create the digital asset',
    copy: 'Export reviewed records and geometry as JSON, CSV, SVG, or DXF with unresolved values identified.',
    screen: exportScreen,
    alt: 'Paperazzi export screen with DXF and SVG actions',
    tone: 'green',
  },
];


const faqs = [
  [
    'What does Paperazzi process?',
    'The current mobile app imports images and scanned PDF pages on iOS and Android. It is designed for aging records, directory pages, unusual layouts, and selected drawing plans.',
  ],
  [
    'Does a document have to leave the device?',
    'No for OCR. Apple Vision and ML Kit run on-device. If cloud enrichment is enabled, the page image and OCR lines are sent to the configured Gemini service, so only permitted, non-sensitive documents should be used.',
  ],
  [
    'Is the AI result automatically trusted?',
    'No. Suggestions are matched to source evidence and checked by deterministic rules. Unsupported, conflicting, or invalid fields are routed to review.',
  ],
  [
    'Which formats can I export?',
    'Reviewed document fields can be saved as JSON or CSV. The controlled drawing workflow can export review-required SVG and DXF geometry after scale calibration.',
  ],
  [
    'Is historical-document accuracy already proven?',
    'Not yet. The repository clearly labels its bundled fixture and current validation boundaries. Real archive accuracy still needs evaluation on permitted, labeled sources.',
  ],
];

function Icon({ name }) {
  const props = {
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.8,
    strokeLinecap: 'round',
    strokeLinejoin: 'round',
    'aria-hidden': true,
  };

  const paths = {
    scan: <><path d="M4 8V4h4M16 4h4v4M20 16v4h-4M8 20H4v-4"/><path d="M8 9h8M8 12h8M8 15h5"/></>,
    evidence: <><path d="M5 3h10l4 4v14H5z"/><path d="M15 3v5h4M8 12h8M8 16h5"/><circle cx="17.5" cy="16.5" r="2.5"/></>,
    review: <><path d="M4 5h16v14H4z"/><path d="m8 12 2.2 2.2L16.5 8M8 8h2"/></>,
    spark: <><path d="m12 3 1.3 4.1L17 9l-3.7 1.9L12 15l-1.3-4.1L7 9l3.7-1.9z"/><path d="m18.5 14 .7 2.3 2.3.7-2.3.7-.7 2.3-.7-2.3-2.3-.7 2.3-.7zM5 14l.8 2.4L8 17.2l-2.2.8L5 20.5 4.2 18 2 17.2l2.2-.8z"/></>,
    drawing: <><path d="M4 19 9 5l5 14M6 14h6"/><path d="M15 6h5v5M15 18h5v-5"/></>,
    export: <><path d="M12 3v12M7.5 10.5 12 15l4.5-4.5"/><path d="M5 14v6h14v-6"/></>,
    github: <><path d="M15 22v-4a4.8 4.8 0 0 0-1-3.5c3.3-.4 6.8-1.6 6.8-7.4A5.8 5.8 0 0 0 19.2 3 5.4 5.4 0 0 0 19 0s-1.2-.4-4 1.6a13.5 13.5 0 0 0-7 0C5.2-.4 4 0 4 0a5.4 5.4 0 0 0-.2 3A5.8 5.8 0 0 0 2.2 7c0 5.8 3.5 7 6.8 7.4A4.8 4.8 0 0 0 8 18v4"/><path d="M8 19c-3 .9-3-1.5-4.2-2"/></>,
    arrow: <><path d="M5 12h14M14 7l5 5-5 5"/></>,
    lock: <><rect x="5" y="10" width="14" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></>,
  };

  return <svg {...props}>{paths[name]}</svg>;
}

function PrimaryLink({ children = 'View on GitHub', className = 'button button-primary' }) {
  return (
    <a className={className} href={REPO_URL} target="_blank" rel="noopener noreferrer">
      {children}
      <Icon name="arrow" />
    </a>
  );
}

function Brand() {
  return (
    <a className="brand" href="#top" aria-label="Paperazzi home">
      <img src={appIcon} alt="" width="48" height="48" />
      <span className="brand-copy">Paperazzi<small>Legacy intelligence</small></span>
    </a>
  );
}

function PhoneFrame({ src, alt, className = '', eager = false }) {
  return (
    <div className={`phone-frame ${className}`.trim()}>
      <div className="phone-screen">
        <img src={src} alt={alt} loading={eager ? 'eager' : 'lazy'} decoding="async" />
      </div>
    </div>
  );
}

function Header() {
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    const closeOnEscape = (event) => {
      if (event.key === 'Escape') setMenuOpen(false);
    };
    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, []);

  return (
    <header className="site-header">
      <nav className="nav container" aria-label="Primary navigation">
        <Brand />
        <div className={`nav-links ${menuOpen ? 'open' : ''}`}>
          <a href="#workflow" onClick={() => setMenuOpen(false)}>Workflow</a>
          <a href="#features" onClick={() => setMenuOpen(false)}>Capabilities</a>
          <a href="#faq" onClick={() => setMenuOpen(false)}>FAQ</a>
        </div>
        <PrimaryLink className="button button-primary nav-cta">Open repository</PrimaryLink>
        <button
          aria-expanded={menuOpen}
          aria-label={menuOpen ? 'Close navigation menu' : 'Open navigation menu'}
          className="menu-button"
          onClick={() => setMenuOpen((open) => !open)}
          type="button"
        >
          <span />
        </button>
      </nav>
    </header>
  );
}

function Hero() {
  return (
    <section className="hero" aria-labelledby="hero-title">
      <div className="container hero-grid">
        <div className="hero-copy reveal reveal-left">
          <h1 id="hero-title">Turn fragile paper into data you can <span className="hero-highlight">trust.</span></h1>
          <p className="hero-subtitle">Turn scanned records into traceable, reviewable data.</p>
          <div className="hero-actions">
            <PrimaryLink />
            <a className="button button-secondary" href="#workflow">See the workflow</a>
          </div>
        </div>

        <div className="hero-visual reveal reveal-right" style={{ '--reveal-delay': '120ms' }}>
          <div className="hero-artboard" aria-hidden="true">
            <span className="hero-blob hero-blob-left" />
            <span className="hero-blob hero-blob-right" />
            <svg className="hero-plane" viewBox="0 0 96 82" fill="none">
              <path d="M9 31 84 7 58 68 42 43 9 31Z" />
              <path d="m42 43 42-36M42 43l-5 26 13-15" />
              <path className="plane-trail" d="M27 72C6 64 2 48 14 39" />
            </svg>
            <div className="hero-note">
              <span>Your</span>
              <span>Documents,</span>
              <span>Reimagined</span>
            </div>
            <svg className="hero-note-arrow" viewBox="0 0 90 90" fill="none">
              <path d="M78 10C48 21 24 43 17 76" />
              <path d="m7 61 10 16 16-8" />
            </svg>
            <span className="hero-doodle doodle-one" />
            <span className="hero-doodle doodle-two" />
            <span className="hero-doodle doodle-three" />
          </div>
          <img
            className="hero-devices"
            src={heroDevices}
            alt="Paperazzi shown across the archivist home, document understanding, and extracted record screens"
            width="1025"
            height="975"
            loading="eager"
            decoding="async"
          />
        </div>
      </div>
    </section>
  );
}

function Workflow() {
  const [activeStep, setActiveStep] = useState(0);
  const stepElements = useRef([]);

  useEffect(() => {
    if (!('IntersectionObserver' in window)) return undefined;
    const observer = new IntersectionObserver(
      (entries) => {
        const activeEntry = entries.find((entry) => entry.isIntersecting);
        if (activeEntry) setActiveStep(Number(activeEntry.target.dataset.step));
      },
      { rootMargin: '-42% 0px -42% 0px' },
    );

    stepElements.current.forEach((element) => element && observer.observe(element));
    return () => observer.disconnect();
  }, []);

  return (
    <section className="workflow" id="workflow" aria-labelledby="workflow-title">
      <div className="container">
        <div className="section-heading reveal">
          <h2 id="workflow-title">From paper to usable knowledge.</h2>
          <p>Four traceable steps from the original document to a reviewed digital asset.</p>
        </div>
        <div className="workflow-grid">
          <div className="workflow-visual reveal reveal-left" aria-hidden="true">
            <div className="workflow-sticky">
              <div className="screen-stage">
                {steps.map((step, index) => (
                  <div className={`screen-layer ${activeStep === index ? 'active' : ''}`} key={step.number}>
                    <PhoneFrame src={step.screen} alt="" className="workflow-phone" eager={index === 0} />
                  </div>
                ))}
                <div className="screen-status"><span>{activeStep + 1}</span>{steps[activeStep].label}</div>
              </div>
            </div>
          </div>
          <ol className="step-list">
            {steps.map((step, index) => (
              <li
                aria-current={activeStep === index ? 'step' : undefined}
                className={`step ${activeStep === index ? 'active' : ''}`}
                data-step={index}
                key={step.number}
                ref={(element) => { stepElements.current[index] = element; }}
              >
                <div className="mobile-step-phone"><PhoneFrame src={step.screen} alt={step.alt} /></div>
                <span className={`step-number ${step.tone}`}>{step.number}</span>
                <div><h3>{step.title}</h3><p>{step.copy}</p></div>
              </li>
            ))}
          </ol>
        </div>
      </div>
    </section>
  );
}

function Features() {
  return (
    <section className="features" id="features" aria-labelledby="features-title">
      <div className="container">
        <div className="section-heading reveal">
          <h2 id="features-title">More than a text extractor.</h2>
          <p>Every capability supports the same goal: reduce manual work without hiding uncertainty.</p>
        </div>
        <div className="feature-grid">
          {features.map((feature, index) => (
            <article className="feature reveal reveal-scale" key={feature.title} style={{ '--reveal-delay': `${index * 60}ms` }}>
              <span className={`feature-icon ${feature.tone}`}><Icon name={feature.icon} /></span>
              <div><h3>{feature.title}</h3><p>{feature.copy}</p></div>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

function Evidence() {
  return (
    <section className="evidence" aria-labelledby="evidence-title">
      <div className="container evidence-card reveal reveal-scale">
        <div className="source-preview">
          <img src={sourceImage} alt="Bundled historical public-works page used as an evaluation fixture" loading="lazy" />
          <span className="source-tag">Bundled evaluation fixture</span>
          <div className="source-box box-one" aria-hidden="true" />
          <div className="source-box box-two" aria-hidden="true" />
        </div>
        <div className="evidence-copy">
          <h2 id="evidence-title">Every field keeps its receipt.</h2>
          <p>Paperazzi links proposed values back to the source page and OCR evidence. Reviewers see what the system saw before they approve anything.</p>
          <ul className="check-list">
            <li><Icon name="review" /> Source crop beside the suggested value</li>
            <li><Icon name="review" /> Clear reasons for review routing</li>
            <li><Icon name="review" /> Original scan never overwritten</li>
          </ul>
          <a className="text-link" href={`${REPO_URL}/blob/main/docs/LEGACYLENS_PLAN.md`} target="_blank" rel="noopener noreferrer">Read the implementation plan <Icon name="arrow" /></a>
        </div>
      </div>
    </section>
  );
}


function Faq() {
  const [open, setOpen] = useState(0);

  return (
    <section className="faq" id="faq" aria-labelledby="faq-title">
      <div className="container faq-grid">
        <div className="faq-intro reveal reveal-left">
          <h2 id="faq-title">Questions worth asking.</h2>
          <p>Paperazzi is an in-progress open-source AppCon project. Its current boundaries are documented alongside the code.</p>
          <div className="privacy-note"><Icon name="lock" /><div><strong>Local by default</strong><span>OCR stays on the device. Cloud AI is optional.</span></div></div>
        </div>
        <div className="faq-list reveal reveal-right">
          {faqs.map(([question, answer], index) => {
            const isOpen = open === index;
            const answerId = `faq-answer-${index}`;
            return (
              <div className={`faq-item ${isOpen ? 'open' : ''}`} key={question}>
                <button className="faq-question" type="button" aria-expanded={isOpen} aria-controls={answerId} onClick={() => setOpen(isOpen ? -1 : index)}>
                  <span>{question}</span><span className="faq-plus" aria-hidden="true">+</span>
                </button>
                <div className="faq-answer" id={answerId} aria-hidden={!isOpen}><div><p>{answer}</p></div></div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}

function FinalCta() {
  return (
    <section className="final" aria-labelledby="final-title">
      <div className="container final-card reveal reveal-scale">
        <div className="final-copy">
          <h2 id="final-title">Make history usable—without losing the source.</h2>
          <p>Open Paperazzi and turn scanned records into traceable, reviewable data.</p>
          <a className="button button-light" href={APP_URL} target="_blank" rel="noopener noreferrer">
            Try the app
            <Icon name="arrow" />
          </a>
        </div>
        <img
          className="final-phone final-phone-art"
          src={finalPhone}
          alt="Paperazzi Document Understanding screen on an angled iPhone"
          width="799"
          height="1028"
          loading="lazy"
          decoding="async"
        />
        <div className="final-mark" aria-hidden="true"><img src={appIcon} alt="" /></div>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="site-footer">
      <div className="container">
        <div className="footer-row">
          <div><Brand /><p>Traceable document intelligence for legacy knowledge.</p></div>
          <nav className="footer-links" aria-label="Footer navigation">
            <a href="#workflow">Workflow</a>
            <a href="#features">Capabilities</a>
            <a href="#faq">FAQ</a>
          </nav>
          <a className="github-link" href={REPO_URL} target="_blank" rel="noopener noreferrer"><Icon name="github" />GitHub</a>
        </div>
        <div className="footer-end"><span>© 2026 Paperazzi · CHEEZCRIBE</span><span>Legacy Knowledge Digitization &amp; Asset Redefinition</span></div>
      </div>
    </footer>
  );
}

function useScrollReveal() {
  useEffect(() => {
    const elements = [...document.querySelectorAll('.reveal')];
    if (!('IntersectionObserver' in window)) {
      elements.forEach((element) => element.classList.add('is-visible'));
      return undefined;
    }
    const observer = new IntersectionObserver(
      (entries) => entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-visible');
        observer.unobserve(entry.target);
      }),
      { rootMargin: '0px 0px -8% 0px', threshold: 0.08 },
    );
    elements.forEach((element) => observer.observe(element));
    return () => observer.disconnect();
  }, []);
}

export default function App() {
  useScrollReveal();
  return (
    <>
      <a className="skip-link" href="#main-content">Skip to content</a>
      <Header />
      <main id="main-content">
        <div id="top" />
        <Hero />
        <Workflow />
        <Features />
        <Evidence />
        <Faq />
        <FinalCta />
      </main>
      <Footer />
      <div className="scroll-blur" aria-hidden="true">
        <span />
        <span />
        <span />
        <span />
        <span />
      </div>
    </>
  );
}
