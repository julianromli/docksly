export const faqUpdated = "Updated September 2026";

export const faqs = [
  {
    question: "What should I do if I find a bug?",
    answer:
      "Send a short report to hello@docksly.app. Include your macOS version and what you did before the problem.",
  },
  {
    question: "How do I hide the menu bar icon?",
    answer:
      "Use System Settings → Menu Bar to hide status items. Docksly stays in the menu extra until you quit it.",
  },
  {
    question: "How many Macs can use one license?",
    answer:
      "Paste your Mayar key on each Mac in Settings → License. There is no device list in the app. Contact us if a key will not activate.",
  },
  {
    question: "How do I recover my license?",
    answer:
      "Open Docksly → Settings → License and paste the Mayar key from your purchase email. See the recover page if you need the steps.",
  },
  {
    question: "Are future updates included?",
    answer:
      "Yes. Docksly is a one-time purchase. Updates stay included. You pay once.",
  },
  {
    question: "Can I try Docksly before I buy it?",
    answer:
      "Yes. The first launch starts a 24-hour trial. After the trial, apply, save, create, delete, import, and export stay locked until you paste a key.",
  },
  {
    question: "Can I get a refund?",
    answer:
      "Write to hello@docksly.app. State the date of purchase and the email you used on Mayar.",
  },
  {
    question: "Will Docksly keep working after macOS updates?",
    answer:
      "Docksly writes the Dock preference list and restarts Dock. That path is not a public AppKit API. Apple can change it. Docksly is sold as is. Test after a major macOS update.",
  },
  {
    question: "Does Docksly collect any data?",
    answer:
      "The Mac app does not collect personal data. There is no account, cloud, or analytics. License check goes to the Docksly license service. This website may use Cloudflare for hosting. Read the privacy policy.",
  },
  {
    question: "What happens to Finder and Trash?",
    answer:
      "Finder stays on the left. Trash stays on the right. Folders and stacks on the right of the divider stay.",
  },
  {
    question: "Do my open apps quit when I switch docks?",
    answer:
      "No. Open apps stay open. An app that is running but not pinned can still show in the Dock until you quit it. That is normal Dock behavior.",
  },
  {
    question: "What Mac do I need?",
    answer:
      "You need macOS 13 or later. Put Docksly in Applications for login-at-login and a reliable menu extra.",
  },
] as const;
