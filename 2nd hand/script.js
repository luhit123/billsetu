const FILTERS = ["All", "SUV", "Sedan", "Bike", "Utility"];

const STORAGE_KEYS = {
  listings: "billeasy-auto-listings",
  conversations: "billeasy-auto-conversations",
  filter: "billeasy-auto-filter",
  activeConversation: "billeasy-auto-active-conversation",
};

const defaultPalette = {
  SUV: { primary: "#ff7b54", secondary: "#ffd9a4" },
  Sedan: { primary: "#6ccdf9", secondary: "#d0f4ff" },
  Bike: { primary: "#7df0a8", secondary: "#d4ffe3" },
  Utility: { primary: "#f7c75b", secondary: "#fff0c4" },
};

const seedListings = [
  {
    id: "listing-nexon-ev",
    title: "2021 Tata Nexon EV XZ+",
    type: "SUV",
    year: 2021,
    price: 1480000,
    mileage: "31,200 km",
    location: "Bengaluru",
    seller: "Rhea Kapoor",
    accent: "#ff7b54",
    description: "Single-owner electric SUV with battery report, fresh tyres, and complete dealer service history.",
  },
  {
    id: "listing-city-zx",
    title: "2019 Honda City ZX CVT",
    type: "Sedan",
    year: 2019,
    price: 980000,
    mileage: "46,900 km",
    location: "Pune",
    seller: "Nikhil Batra",
    accent: "#68d8ff",
    description: "Comfortable city sedan with sunroof, automatic gearbox, and clean insurance record.",
  },
  {
    id: "listing-hunter-350",
    title: "2022 Royal Enfield Hunter 350",
    type: "Bike",
    year: 2022,
    price: 168000,
    mileage: "12,300 km",
    location: "Jaipur",
    seller: "Aditi Sharma",
    accent: "#8af2bc",
    description: "Well-kept street bike with tasteful accessories, recent service, and great city mileage.",
  },
  {
    id: "listing-bolero-pickup",
    title: "2020 Mahindra Bolero Pickup",
    type: "Utility",
    year: 2020,
    price: 760000,
    mileage: "58,000 km",
    location: "Ahmedabad",
    seller: "Harsh Patel",
    accent: "#f6c863",
    description: "Reliable utility pickup with strong loading history, maintained engine, and fresh permit paperwork.",
  },
  {
    id: "listing-brezza-vxi",
    title: "2022 Maruti Brezza VXi",
    type: "SUV",
    year: 2022,
    price: 1140000,
    mileage: "18,600 km",
    location: "Hyderabad",
    seller: "Sana Mirza",
    accent: "#ff8f6b",
    description: "Compact SUV with touchscreen, reverse camera, and a spotless interior ready for its next owner.",
  },
  {
    id: "listing-verna-sx",
    title: "2021 Hyundai Verna SX Turbo",
    type: "Sedan",
    year: 2021,
    price: 1295000,
    mileage: "27,400 km",
    location: "Chennai",
    seller: "Varun Iyer",
    accent: "#6ccdf9",
    description: "Sharp-looking sedan with punchy turbo engine, updated infotainment, and full records.",
  },
];

const seedConversations = {
  "listing-nexon-ev": [
    {
      sender: "seller",
      text: "Hi! The battery health report and service records are ready if you'd like to see them.",
      time: "09:12 AM",
    },
    {
      sender: "buyer",
      text: "That sounds great. Has the car had any accident repairs or paint work?",
      time: "09:18 AM",
    },
    {
      sender: "seller",
      text: "No accident history. I can also share the latest inspection photos before you visit.",
      time: "09:22 AM",
    },
  ],
  "listing-city-zx": [
    {
      sender: "seller",
      text: "The car is available this weekend if you want to check the automatic gearbox in traffic.",
      time: "08:40 AM",
    },
  ],
  "listing-hunter-350": [
    {
      sender: "seller",
      text: "Fresh service done last month. Chain set and brake pads were replaced as well.",
      time: "10:05 AM",
    },
    {
      sender: "buyer",
      text: "Nice. Is the registration transfer straightforward in Jaipur?",
      time: "10:14 AM",
    },
  ],
  "listing-bolero-pickup": [
    {
      sender: "seller",
      text: "Useful for city delivery routes. Permit and tax documents are current through next year.",
      time: "07:55 AM",
    },
  ],
  "listing-brezza-vxi": [
    {
      sender: "seller",
      text: "The reverse camera and touchscreen are in perfect working condition.",
      time: "11:20 AM",
    },
  ],
  "listing-verna-sx": [
    {
      sender: "seller",
      text: "I can share highway mileage numbers and service bills if you are comparing it with the City.",
      time: "12:02 PM",
    },
  ],
};

const state = {
  listings: loadListings(),
  conversations: loadConversations(),
  activeFilter: localStorage.getItem(STORAGE_KEYS.filter) || "All",
  activeConversationId: localStorage.getItem(STORAGE_KEYS.activeConversation) || "",
};

const filterBar = document.querySelector("#filterBar");
const listingGrid = document.querySelector("#listingGrid");
const listingForm = document.querySelector("#listingForm");
const previewImage = document.querySelector("#previewImage");
const previewType = document.querySelector("#previewType");
const previewTitle = document.querySelector("#previewTitle");
const previewPrice = document.querySelector("#previewPrice");
const previewLocation = document.querySelector("#previewLocation");
const previewDescription = document.querySelector("#previewDescription");
const listingCount = document.querySelector("#listingCount");
const sellerCount = document.querySelector("#sellerCount");
const pulseTotal = document.querySelector("#pulseTotal");
const pulseSuv = document.querySelector("#pulseSuv");
const pulseBike = document.querySelector("#pulseBike");
const pulseHotCity = document.querySelector("#pulseHotCity");
const pulseHotCityCopy = document.querySelector("#pulseHotCityCopy");
const pulseSeller = document.querySelector("#pulseSeller");
const conversationCount = document.querySelector("#conversationCount");
const conversationList = document.querySelector("#conversationList");
const messageThread = document.querySelector("#messageThread");
const messageForm = document.querySelector("#messageForm");
const chatTitle = document.querySelector("#chatTitle");
const chatSubline = document.querySelector("#chatSubline");
const toast = document.querySelector("#toast");

let toastTimer = 0;

function loadListings() {
  const stored = safeRead(STORAGE_KEYS.listings);
  if (!stored) {
    return seedListings.map((listing) => ({
      ...listing,
      image: buildVehicleArt(listing.type, listing.accent),
    }));
  }

  return stored.map((listing) => ({
    ...listing,
    image: listing.image || buildVehicleArt(listing.type, listing.accent),
  }));
}

function loadConversations() {
  return safeRead(STORAGE_KEYS.conversations) || seedConversations;
}

function safeRead(key) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : null;
  } catch (error) {
    console.warn("Unable to read saved state", error);
    return null;
  }
}

function saveState() {
  localStorage.setItem(STORAGE_KEYS.listings, JSON.stringify(state.listings));
  localStorage.setItem(STORAGE_KEYS.conversations, JSON.stringify(state.conversations));
  localStorage.setItem(STORAGE_KEYS.filter, state.activeFilter);
  localStorage.setItem(STORAGE_KEYS.activeConversation, state.activeConversationId);
}

function encodeSvg(svg) {
  return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`;
}

function buildVehicleArt(type, accent) {
  const palette = defaultPalette[type] || defaultPalette.SUV;
  const primary = accent || palette.primary;
  const secondary = palette.secondary;
  const silhouettes = {
    SUV: `
      <path d="M110 310c24-6 47-56 82-82 20-16 46-24 81-24h147c40 0 69 12 92 36 19 20 32 41 45 70h44c21 0 39 17 39 38v18H88v-22c0-18 11-31 22-34z" fill="url(#vehicle)" />
      <path d="M247 216h188c26 0 47 6 63 18 17 12 29 28 42 52H186c14-22 29-40 61-60z" fill="rgba(255,255,255,0.45)" />
    `,
    Sedan: `
      <path d="M122 316c27-4 49-44 80-78 19-21 43-30 79-30h150c35 0 64 13 84 37 15 18 27 38 34 59h43c20 0 38 16 38 36v24H102v-21c0-14 8-25 20-27z" fill="url(#vehicle)" />
      <path d="M232 218h178c20 0 38 3 54 13 18 11 30 27 45 52H177c17-30 32-47 55-57z" fill="rgba(255,255,255,0.48)" />
    `,
    Bike: `
      <circle cx="240" cy="350" r="56" fill="#101d1f" />
      <circle cx="552" cy="350" r="56" fill="#101d1f" />
      <circle cx="240" cy="350" r="28" fill="#d7efe5" />
      <circle cx="552" cy="350" r="28" fill="#d7efe5" />
      <path d="M310 292h94l58-55 38 15-54 54 48 0c22 0 37 6 51 20l-19 19c-8-8-16-12-28-12h-51l-24-29-61 0-36 46h-29l54-58-19-32-42 0-22 33h-31l29-53c8-15 21-22 39-22z" fill="url(#vehicle)" />
      <rect x="428" y="211" width="60" height="16" rx="8" fill="#f7efe1" transform="rotate(11 428 211)" />
    `,
    Utility: `
      <path d="M114 307c34 0 60-64 97-85 18-11 39-16 65-16h115c27 0 49 8 64 24l38 41h83c17 0 31 14 31 31v58H91v-24c0-16 9-29 23-29z" fill="url(#vehicle)" />
      <rect x="418" y="214" width="143" height="64" rx="14" fill="rgba(255,255,255,0.26)" />
      <path d="M193 289c13-23 28-42 55-58h154c27 0 46 14 64 58H193z" fill="rgba(255,255,255,0.48)" />
    `,
  };

  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 520" fill="none">
      <defs>
        <linearGradient id="bg" x1="120" y1="48" x2="690" y2="458" gradientUnits="userSpaceOnUse">
          <stop stop-color="#0a181a" />
          <stop offset="1" stop-color="#183336" />
        </linearGradient>
        <linearGradient id="vehicle" x1="150" y1="240" x2="620" y2="384" gradientUnits="userSpaceOnUse">
          <stop stop-color="${primary}" />
          <stop offset="1" stop-color="${secondary}" />
        </linearGradient>
      </defs>
      <rect width="800" height="520" rx="48" fill="url(#bg)" />
      <circle cx="618" cy="110" r="86" fill="${primary}" fill-opacity="0.24" />
      <circle cx="196" cy="102" r="118" fill="${secondary}" fill-opacity="0.18" />
      <path d="M0 398c124-33 259-53 393-53 153 0 274 19 407 58V520H0V398z" fill="#0e2022" />
      <path d="M95 390c143-29 243-38 382-38 100 0 212 14 302 41" stroke="rgba(255,255,255,0.13)" stroke-width="3" stroke-linecap="round" />
      ${silhouettes[type] || silhouettes.SUV}
      <circle cx="232" cy="360" r="52" fill="#101d1f" />
      <circle cx="566" cy="360" r="52" fill="#101d1f" />
      <circle cx="232" cy="360" r="23" fill="#ebf4e8" />
      <circle cx="566" cy="360" r="23" fill="#ebf4e8" />
      <rect x="516" y="82" width="112" height="54" rx="18" fill="rgba(255,255,255,0.1)" />
      <path d="M547 134l-5 16 17-13 34 0c17 0 31-14 31-31V82" stroke="rgba(255,255,255,0.24)" stroke-width="3" stroke-linecap="round" />
      <rect x="548" y="96" width="47" height="8" rx="4" fill="#e8f6ff" fill-opacity="0.8" />
      <rect x="548" y="111" width="32" height="8" rx="4" fill="#e8f6ff" fill-opacity="0.5" />
    </svg>
  `;

  return encodeSvg(svg);
}

function formatPrice(amount) {
  return `INR ${new Intl.NumberFormat("en-IN", {
    maximumFractionDigits: 0,
  }).format(amount)}`;
}

function getListing(id) {
  return state.listings.find((listing) => listing.id === id);
}

function getMessages(id) {
  return state.conversations[id] || [];
}

function getTypeCount(type) {
  return state.listings.filter((listing) => listing.type === type).length;
}

function getTopLocation() {
  const locationCounts = state.listings.reduce((counts, listing) => {
    counts[listing.location] = (counts[listing.location] || 0) + 1;
    return counts;
  }, {});

  const [city = "Bengaluru", count = 0] = Object.entries(locationCounts).sort((left, right) => {
    return right[1] - left[1];
  })[0] || ["Bengaluru", 0];

  return { city, count };
}

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function renderFilters() {
  filterBar.innerHTML = FILTERS.map(
    (filter) => `
      <button
        class="filter-pill ${filter === state.activeFilter ? "active" : ""}"
        type="button"
        data-filter="${filter}"
        role="tab"
        aria-selected="${filter === state.activeFilter}"
      >
        ${filter}
      </button>
    `,
  ).join("");

  filterBar.querySelectorAll("[data-filter]").forEach((button) => {
    button.addEventListener("click", () => {
      state.activeFilter = button.dataset.filter;
      saveState();
      renderFilters();
      renderListings();
    });
  });
}

function renderListings() {
  const filteredListings = state.listings.filter((listing) => {
    if (state.activeFilter === "All") {
      return true;
    }
    return listing.type === state.activeFilter;
  });

  if (!filteredListings.length) {
    listingGrid.innerHTML = `
      <article class="listing-empty">
        No listings match this filter yet. Add a fresh vehicle above and it will appear here instantly.
      </article>
    `;
    updateSummaryStats();
    return;
  }

  listingGrid.innerHTML = filteredListings
    .map(
      (listing) => `
        <article class="listing-card" data-listing-id="${listing.id}">
          <div class="listing-media">
            <img src="${listing.image}" alt="${escapeHtml(listing.title)}" />
            <span class="listing-badge">${escapeHtml(listing.type)}</span>
          </div>
          <div class="listing-body">
            <div class="listing-topline">
              <div>
                <h3>${escapeHtml(listing.title)}</h3>
                <span class="listing-subline">${listing.year} / ${escapeHtml(listing.location)}</span>
              </div>
              <strong class="listing-price">${formatPrice(listing.price)}</strong>
            </div>
            <div class="listing-details">
              <span>${escapeHtml(listing.mileage)}</span>
              <span>${escapeHtml(listing.seller)}</span>
            </div>
            <p class="listing-description">${escapeHtml(listing.description)}</p>
            <div class="listing-footer">
              <button class="listing-link" type="button" data-open-chat="${listing.id}">
                View chat
              </button>
              <button class="listing-chat" type="button" data-focus-listing="${listing.id}">
                Message seller
              </button>
            </div>
          </div>
        </article>
      `,
    )
    .join("");

  listingGrid.querySelectorAll("[data-open-chat], [data-focus-listing]").forEach((button) => {
    button.addEventListener("click", (event) => {
      event.stopPropagation();
      const listingId = event.currentTarget.dataset.openChat || event.currentTarget.dataset.focusListing;
      setActiveConversation(listingId, true);
    });
  });

  listingGrid.querySelectorAll(".listing-card").forEach((card) => {
    card.addEventListener("click", () => setActiveConversation(card.dataset.listingId, true));
  });

  updateSummaryStats();
}

function updateSummaryStats() {
  const totalListings = state.listings.length;
  const totalSellers = new Set(state.listings.map((listing) => listing.seller)).size;

  listingCount.textContent = String(totalListings);
  sellerCount.textContent = String(totalSellers);
  conversationCount.textContent = `${state.listings.length} chats`;
  updatePulseStats(totalListings, totalSellers);
}

function updatePulseStats(totalListings, totalSellers) {
  const suvCount = getTypeCount("SUV");
  const bikeCount = getTypeCount("Bike");
  const topLocation = getTopLocation();

  if (pulseTotal) {
    pulseTotal.textContent = String(totalListings);
  }

  if (pulseSuv) {
    pulseSuv.textContent = String(suvCount);
  }

  if (pulseBike) {
    pulseBike.textContent = String(bikeCount);
  }

  if (pulseSeller) {
    pulseSeller.textContent = String(totalSellers);
  }

  if (pulseHotCity) {
    pulseHotCity.textContent = topLocation.city;
  }

  if (pulseHotCityCopy) {
    const listingWord = topLocation.count === 1 ? "listing" : "listings";
    pulseHotCityCopy.textContent = `${topLocation.count} active ${listingWord} attracting nearby buyer interest.`;
  }
}

function renderConversations() {
  conversationList.innerHTML = state.listings
    .map((listing) => {
      const messages = getMessages(listing.id);
      const latestMessage = messages[messages.length - 1];
      const initials = listing.seller
        .split(" ")
        .map((part) => part[0])
        .slice(0, 2)
        .join("");

      return `
        <button
          class="conversation-item ${listing.id === state.activeConversationId ? "active" : ""}"
          type="button"
          data-conversation="${listing.id}"
        >
          <span class="conversation-avatar">${initials}</span>
          <div class="conversation-copy">
            <strong>${escapeHtml(listing.seller)}</strong>
            <span>${escapeHtml(listing.title)}</span>
            <p>${escapeHtml(latestMessage ? latestMessage.text : "No messages yet. Start the conversation.")}</p>
          </div>
        </button>
      `;
    })
    .join("");

  conversationList.querySelectorAll("[data-conversation]").forEach((button) => {
    button.addEventListener("click", () => setActiveConversation(button.dataset.conversation));
  });
}

function renderActiveConversation() {
  const listing = getListing(state.activeConversationId);

  if (!listing) {
    chatTitle.textContent = "Choose a listing";
    chatSubline.textContent = "Tap a listing card or conversation to start.";
    messageThread.innerHTML = `
      <div class="message-empty">
        Pick a vehicle to open its linked conversation. Buyers and sellers will appear here.
      </div>
    `;
    return;
  }

  const messages = getMessages(listing.id);
  chatTitle.textContent = `${listing.seller} / ${listing.title}`;
  chatSubline.textContent = `${listing.location} / ${formatPrice(listing.price)} / ${listing.mileage}`;

  if (!messages.length) {
    messageThread.innerHTML = `
      <div class="message-empty">
        No messages yet. Ask about service history, documents, pricing, or schedule a test drive.
      </div>
    `;
    return;
  }

  messageThread.innerHTML = messages
    .map(
      (message) => `
        <div class="message-bubble ${message.sender}">
          <p>${escapeHtml(message.text)}</p>
          <span>${message.time}</span>
        </div>
      `,
    )
    .join("");

  messageThread.scrollTop = messageThread.scrollHeight;
}

function setActiveConversation(listingId, scrollIntoView = false) {
  state.activeConversationId = listingId;
  saveState();
  renderConversations();
  renderActiveConversation();

  if (scrollIntoView) {
    document.querySelector("#messages")?.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

function getCurrentTimeLabel() {
  return new Date().toLocaleTimeString("en-IN", {
    hour: "2-digit",
    minute: "2-digit",
  });
}

function sendMessage(text, sender = "buyer", conversationId = state.activeConversationId) {
  if (!conversationId) {
    showToast("Pick a listing first so the message has somewhere to go.");
    return false;
  }

  const thread = getMessages(conversationId);
  thread.push({
    sender,
    text,
    time: getCurrentTimeLabel(),
  });
  state.conversations[conversationId] = thread;
  saveState();
  renderConversations();
  if (conversationId === state.activeConversationId) {
    renderActiveConversation();
  }
  return true;
}

function autoReply(listing) {
  const replies = [
    `Happy to help. I can share more photos of the ${listing.title} if you want a closer look.`,
    `Yes, the paperwork is ready. We can also plan a quick inspection in ${listing.location}.`,
    `Thanks for the message. I can talk through the final price once you've seen the vehicle.`,
    `Absolutely. I have recent service details and can send them over in chat.`,
  ];

  const reply = replies[Math.floor(Math.random() * replies.length)];
  sendMessage(reply, "seller", listing.id);
}

function handleMessageSubmit(event) {
  event.preventDefault();

  const formData = new FormData(messageForm);
  const text = (formData.get("message") || "").toString().trim();

  if (!text) {
    return;
  }

  const activeListing = getListing(state.activeConversationId);
  const wasSent = sendMessage(text, "buyer", activeListing?.id);
  if (!wasSent) {
    return;
  }
  messageForm.reset();

  if (activeListing) {
    window.setTimeout(() => autoReply(activeListing), 900);
  }
}

function readFileAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}

async function handleListingSubmit(event) {
  event.preventDefault();

  const formData = new FormData(listingForm);
  const seller = formData.get("seller").toString().trim();
  const title = formData.get("title").toString().trim();
  const type = formData.get("type").toString();
  const year = Number(formData.get("year"));
  const price = Number(formData.get("price"));
  const mileage = formData.get("mileage").toString().trim();
  const location = formData.get("location").toString().trim();
  const description = formData.get("description").toString().trim();
  const imageFile = formData.get("image");

  if (!seller || !title || !year || !price || !mileage || !location || !description) {
    showToast("Please fill out all required vehicle details.");
    return;
  }

  let image = buildVehicleArt(type, defaultPalette[type]?.primary);
  if (imageFile instanceof File && imageFile.size > 0) {
    image = await readFileAsDataUrl(imageFile);
  }

  const listing = {
    id: `listing-${Date.now()}`,
    seller,
    title,
    type,
    year,
    price,
    mileage,
    location,
    description,
    accent: defaultPalette[type]?.primary || defaultPalette.SUV.primary,
    image,
  };

  state.listings.unshift(listing);
  state.conversations[listing.id] = [
    {
      sender: "seller",
      text: `Hi! Thanks for checking out my ${title}. I'm happy to share more details or book a viewing.`,
      time: getCurrentTimeLabel(),
    },
  ];

  listingForm.reset();
  syncPreview();
  state.activeFilter = "All";
  setActiveConversation(listing.id);
  saveState();
  renderFilters();
  renderListings();
  renderConversations();
  renderActiveConversation();
  showToast("Listing published. Buyers can now discover it and start chatting.");
  document.querySelector("#marketplace")?.scrollIntoView({ behavior: "smooth", block: "start" });
}

function syncPreview() {
  const sellerField = listingForm.elements.seller;
  const titleField = listingForm.elements.title;
  const typeField = listingForm.elements.type;
  const priceField = listingForm.elements.price;
  const locationField = listingForm.elements.location;
  const descriptionField = listingForm.elements.description;
  const fileField = listingForm.elements.image;

  const type = typeField.value || "SUV";
  const title = titleField.value.trim() || "2021 Hyundai Creta SX";
  const price = Number(priceField.value) ? formatPrice(Number(priceField.value)) : "INR 8,50,000";
  const location = locationField.value.trim() || "Pune";
  const description =
    descriptionField.value.trim() ||
    "Single-owner vehicle, full service history, fresh tyres, and clean papers.";

  previewType.textContent = type;
  previewTitle.textContent = title;
  previewPrice.textContent = price;
  previewLocation.textContent = location;
  previewDescription.textContent = description;

  const maybeFile = fileField.files?.[0];
  if (maybeFile) {
    readFileAsDataUrl(maybeFile)
      .then((result) => {
        previewImage.src = result;
      })
      .catch(() => {
        previewImage.src = buildVehicleArt(type, defaultPalette[type]?.primary);
      });
    return;
  }

  previewImage.src = buildVehicleArt(type, defaultPalette[type]?.primary);
  previewImage.alt = `${type} preview generated for ${title}`;

  if (sellerField.value.trim()) {
    previewDescription.textContent = `${description} Listed by ${sellerField.value.trim()}.`;
  }
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.add("visible");
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => toast.classList.remove("visible"), 2200);
}

function initFormPreview() {
  listingForm.querySelectorAll("input, select, textarea").forEach((field) => {
    field.addEventListener("input", syncPreview);
    field.addEventListener("change", syncPreview);
  });
  syncPreview();
}

function init() {
  renderFilters();
  renderListings();
  renderConversations();
  initFormPreview();

  if (!getListing(state.activeConversationId)) {
    state.activeConversationId = state.listings[0]?.id || "";
  }

  saveState();
  renderConversations();
  renderActiveConversation();

  listingForm.addEventListener("submit", handleListingSubmit);
  messageForm.addEventListener("submit", handleMessageSubmit);
}

init();
