// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item expanded "><a href="index.html"><strong aria-hidden="true">1.</strong> Home</a></li><li class="chapter-item expanded "><a href="architecture/overview.html"><strong aria-hidden="true">2.</strong> Architecture</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="architecture/EthMultiVault.html"><strong aria-hidden="true">2.1.</strong> EthMultiVault</a></li><li class="chapter-item expanded "><a href="architecture/BondingCurveRegistry.html"><strong aria-hidden="true">2.2.</strong> BondingCurveRegistry</a></li><li class="chapter-item expanded "><a href="architecture/BaseCurve.html"><strong aria-hidden="true">2.3.</strong> BaseCurve</a></li><li class="chapter-item expanded "><a href="architecture/LinearCurve.html"><strong aria-hidden="true">2.4.</strong> LinearCurve</a></li><li class="chapter-item expanded "><a href="architecture/ProgressiveCurve.html"><strong aria-hidden="true">2.5.</strong> ProgressiveCurve</a></li><li class="chapter-item expanded "><a href="architecture/AtomWallet.html"><strong aria-hidden="true">2.6.</strong> AtomWallet</a></li><li class="chapter-item expanded "><a href="architecture/Attestoor.html"><strong aria-hidden="true">2.7.</strong> Attestoor</a></li><li class="chapter-item expanded "><a href="architecture/AttestoorFactory.html"><strong aria-hidden="true">2.8.</strong> AttestoorFactory</a></li><li class="chapter-item expanded "><a href="architecture/CustomMulticall3.html"><strong aria-hidden="true">2.9.</strong> CustomMulticall3</a></li></ol></li><li class="chapter-item expanded "><li class="part-title">src</li><li class="chapter-item expanded affix "><li class="part-title">src</li><li class="chapter-item expanded "><a href="src/interfaces/index.html"><strong aria-hidden="true">3.</strong> ❱ interfaces</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="src/interfaces/IBaseCurve.sol/interface.IBaseCurve.html"><strong aria-hidden="true">3.1.</strong> IBaseCurve</a></li><li class="chapter-item expanded "><a href="src/interfaces/IBondingCurveRegistry.sol/interface.IBondingCurveRegistry.html"><strong aria-hidden="true">3.2.</strong> IBondingCurveRegistry</a></li><li class="chapter-item expanded "><a href="src/interfaces/IEthMultiVault.sol/interface.IEthMultiVault.html"><strong aria-hidden="true">3.3.</strong> IEthMultiVault</a></li><li class="chapter-item expanded "><a href="src/interfaces/IPermit2.sol/interface.IPermit2.html"><strong aria-hidden="true">3.4.</strong> IPermit2</a></li></ol></li><li class="chapter-item expanded "><a href="src/libraries/index.html"><strong aria-hidden="true">4.</strong> ❱ libraries</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="src/libraries/Errors.sol/library.Errors.html"><strong aria-hidden="true">4.1.</strong> Errors</a></li></ol></li><li class="chapter-item expanded "><a href="src/utils/index.html"><strong aria-hidden="true">5.</strong> ❱ utils</a></li><li><ol class="section"><li class="chapter-item expanded "><a href="src/utils/Attestoor.sol/contract.Attestoor.html"><strong aria-hidden="true">5.1.</strong> Attestoor</a></li><li class="chapter-item expanded "><a href="src/utils/AttestoorFactory.sol/contract.AttestoorFactory.html"><strong aria-hidden="true">5.2.</strong> AttestoorFactory</a></li><li class="chapter-item expanded "><a href="src/utils/CustomMulticall3.sol/contract.CustomMulticall3.html"><strong aria-hidden="true">5.3.</strong> CustomMulticall3</a></li><li class="chapter-item expanded "><a href="src/utils/Multicall3.sol/contract.Multicall3.html"><strong aria-hidden="true">5.4.</strong> Multicall3</a></li></ol></li><li class="chapter-item expanded "><a href="src/AtomWallet.sol/contract.AtomWallet.html"><strong aria-hidden="true">6.</strong> AtomWallet</a></li><li class="chapter-item expanded "><a href="src/BaseCurve.sol/abstract.BaseCurve.html"><strong aria-hidden="true">7.</strong> BaseCurve</a></li><li class="chapter-item expanded "><a href="src/BondingCurveRegistry.sol/contract.BondingCurveRegistry.html"><strong aria-hidden="true">8.</strong> BondingCurveRegistry</a></li><li class="chapter-item expanded "><a href="src/EthMultiVault.sol/contract.EthMultiVault.html"><strong aria-hidden="true">9.</strong> EthMultiVault</a></li><li class="chapter-item expanded "><a href="src/LinearCurve.sol/contract.LinearCurve.html"><strong aria-hidden="true">10.</strong> LinearCurve</a></li><li class="chapter-item expanded "><a href="src/ProgressiveCurve.sol/contract.ProgressiveCurve.html"><strong aria-hidden="true">11.</strong> ProgressiveCurve</a></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString().split("#")[0];
        if (current_page.endsWith("/")) {
            current_page += "index.html";
        }
        var links = Array.prototype.slice.call(this.querySelectorAll("a"));
        var l = links.length;
        for (var i = 0; i < l; ++i) {
            var link = links[i];
            var href = link.getAttribute("href");
            if (href && !href.startsWith("#") && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The "index" page is supposed to alias the first chapter in the book.
            if (link.href === current_page || (i === 0 && path_to_root === "" && current_page.endsWith("/index.html"))) {
                link.classList.add("active");
                var parent = link.parentElement;
                if (parent && parent.classList.contains("chapter-item")) {
                    parent.classList.add("expanded");
                }
                while (parent) {
                    if (parent.tagName === "LI" && parent.previousElementSibling) {
                        if (parent.previousElementSibling.classList.contains("chapter-item")) {
                            parent.previousElementSibling.classList.add("expanded");
                        }
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', function(e) {
            if (e.target.tagName === 'A') {
                sessionStorage.setItem('sidebar-scroll', this.scrollTop);
            }
        }, { passive: true });
        var sidebarScrollTop = sessionStorage.getItem('sidebar-scroll');
        sessionStorage.removeItem('sidebar-scroll');
        if (sidebarScrollTop) {
            // preserve sidebar scroll position when navigating via links within sidebar
            this.scrollTop = sidebarScrollTop;
        } else {
            // scroll sidebar to current active section when navigating via "next/previous chapter" buttons
            var activeSection = document.querySelector('#sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        var sidebarAnchorToggles = document.querySelectorAll('#sidebar a.toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(function (el) {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define("mdbook-sidebar-scrollbox", MDBookSidebarScrollbox);
