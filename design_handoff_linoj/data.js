// Shared sample data for LinoJ
// Urgency: 'urgent' | 'normal'  — todos are time-agnostic

window.LinoJData = {
  today: { weekday: 'Tuesday', date: 'May 27', year: 2026, iso: '2026-05-27' },

  personalTodos: [
    { id: 'p1', title: 'Read《人类简史》Ch. 3', urgency: 'normal', done: false },
    { id: 'p2', title: 'Renew gym membership', urgency: 'normal', done: false },
    { id: 'p3', title: 'Pick up dry cleaning', urgency: 'normal', done: false },
    { id: 'p4', title: 'Buy birthday gift for L', urgency: 'normal', done: false },
    { id: 'p5', title: 'Reply to mom', urgency: 'urgent', done: false },
    { id: 'p6', title: 'Move savings into HYSA', urgency: 'urgent', done: false },
    { id: 'p7', title: 'Schedule dentist', urgency: 'normal', done: true },
  ],

  workTodos: [
    { id: 'w1', title: 'Submit Q1 expense report', urgency: 'urgent', done: false, project: null },
    { id: 'w2', title: 'Review legal redlines', urgency: 'normal', done: false, project: null },
    { id: 'w3', title: 'Approve design system PR', urgency: 'normal', done: false, project: null },
    { id: 'w4', title: 'Finalize macOS sidebar spec', urgency: 'urgent', done: false, project: 'linoj' },
    { id: 'w5', title: 'Review onboarding copy v2', urgency: 'urgent', done: false, project: 'onboarding' },
    { id: 'w6', title: 'Sync with @Mei on launch deck', urgency: 'normal', done: false, project: 'q3' },
    { id: 'w7', title: 'Polish empty states', urgency: 'normal', done: false, project: 'linoj' },
    { id: 'w8', title: 'Audit color tokens', urgency: 'normal', done: false, project: 'linoj' },
    { id: 'w9', title: 'Draft Q3 OKR doc', urgency: 'normal', done: true, project: 'q3' },
  ],

  projects: [
    {
      id: 'linoj',
      title: 'LinoJ for macOS v1',
      intro: 'Native Swift planner. Three intertwined surfaces — personal, work, and time — pulled into one calm workspace.',
      notes: 'Shipping target end of June. Sidebar spec is the last blocker. Andy is owning visual, Mei is owning the data model. Linus signs off Friday.\n\nOpen questions: do we ship dark mode at v1? How do widgets fit?',
      tag: 'Shipping June',
      members: ['L', 'M', 'A'],
      createdAt: 'Apr 12',
    },
    {
      id: 'onboarding',
      title: 'Onboarding redesign',
      intro: 'Cut the first-run flow from 7 screens to 3. Lean on empty states that teach instead of explain.',
      notes: 'Concept locked. Mei drafting copy v2 — due before Fri crit.',
      tag: 'In review',
      members: ['M', 'J'],
      createdAt: 'May 3',
    },
    {
      id: 'q3',
      title: 'Q3 planning',
      intro: 'Align the team on three bets for the quarter. Draft → review → commit.',
      notes: 'Drafts are in. Final commit review on Wed.',
      tag: 'Almost done',
      members: ['L', 'M', 'A', 'J', 'K'],
      createdAt: 'May 15',
    },
  ],

  // Calendar — strictly time + place + people (no todos)
  events: [
    { id: 'e1', title: 'Morning standup', day: 'Tue', start: 9.5, end: 10, where: 'Zoom', who: ['M', 'A', 'J'], project: 'linoj' },
    { id: 'e2', title: '1:1 with Mei', day: 'Tue', start: 11, end: 11.5, where: 'Blue Bottle, Hayes', who: ['M'], project: null },
    { id: 'e3', title: 'Design review — sidebar', day: 'Tue', start: 14, end: 15, where: 'Conf Rm A', who: ['M', 'A'], project: 'linoj' },
    { id: 'e4', title: 'Dinner with parents', day: 'Tue', start: 19, end: 20.5, where: 'Home', who: ['Mom', 'Dad'], project: null },
    { id: 'e5', title: 'Onboarding crit', day: 'Wed', start: 10, end: 11, where: 'Conf Rm C', who: ['M', 'J'], project: 'onboarding' },
    { id: 'e6', title: 'Q3 commit review', day: 'Wed', start: 15, end: 16.5, where: 'Conf Rm A', who: ['L', 'M', 'A', 'J'], project: 'q3' },
    { id: 'e7', title: 'Yoga', day: 'Wed', start: 18.5, end: 19.5, where: 'Mission Studio', who: [], project: null },
    { id: 'e8', title: 'Eng sync', day: 'Thu', start: 9, end: 10, where: 'Zoom', who: ['M', 'K'], project: 'linoj' },
    { id: 'e9', title: 'Lunch w/ Andrew', day: 'Thu', start: 12, end: 13, where: 'Tartine', who: ['Andrew'], project: null },
    { id: 'e10', title: 'Shipping retro', day: 'Fri', start: 14, end: 15, where: 'Conf Rm B', who: ['M', 'A', 'J', 'K'], project: 'linoj' },
    { id: 'e11', title: 'Therapy', day: 'Fri', start: 17, end: 18, where: 'Mission St', who: [], project: null },
    { id: 'e12', title: 'Brunch with K', day: 'Sat', start: 11, end: 13, where: 'Tartine Manufactory', who: ['K'], project: null },
    { id: 'e13', title: 'Long run', day: 'Sat', start: 7.5, end: 9, where: 'Crissy Field', who: [], project: null },
    { id: 'e14', title: 'Call with parents', day: 'Sun', start: 10, end: 11, where: 'FaceTime', who: ['Mom', 'Dad'], project: null },
    { id: 'e15', title: 'LinoJ kickoff v2', day: 'Mon2', start: 10, end: 11.5, where: 'Conf Rm A', who: ['L', 'M', 'A', 'J'], project: 'linoj' },
    { id: 'e16', title: 'Dentist', day: 'Mon2', start: 15.5, end: 16.5, where: 'Pacific Dental', who: [], project: null },
  ],

  // Yesterday's events not yet checked off as attended.
  yesterdayEvents: [
    { id: 'y1', title: 'Engineering standup', start: 9.5, end: 10, where: 'Zoom', who: ['M', 'A'], project: 'linoj' },
    { id: 'y2', title: 'Coffee with Andrew', start: 15, end: 16, where: 'Sightglass', who: ['Andrew'], project: null },
  ],

  // Rolling next-7-days, starting from today (Tue).
  weekDays: [
    { key: 'Tue', label: 'Today', date: 27, today: true },
    { key: 'Wed', label: 'Wed', date: 28 },
    { key: 'Thu', label: 'Thu', date: 29 },
    { key: 'Fri', label: 'Fri', date: 30 },
    { key: 'Sat', label: 'Sat', date: 31, weekend: true },
    { key: 'Sun', label: 'Sun', date: 1, weekend: true },
    { key: 'Mon2', label: 'Mon', date: 2 },
  ],
};
