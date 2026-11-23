
class AlumniData {
  final String userId;
  final String name;
  final String initials;
  final String job;
  final String company;
  final String department;
  final String graduationYear;
  final int matchPercentage;
  final String matchReason;
  final String about;
  final List<String> canHelpWith;

  const AlumniData({
    this.userId = '',
    required this.name,
    required this.initials,
    required this.job,
    required this.company,
    required this.department,
    required this.graduationYear,
    required this.matchPercentage,
    required this.matchReason,
    required this.about,
    required this.canHelpWith,
  });
}

// Sample data retained for existing parts of the app.
// The AI Matches screen will no longer use this list.
const List<AlumniData> alumniList = [
  AlumniData(
    name: 'Sarah Ahmed',
    initials: 'SA',
    job: 'Software Engineer',
    company: 'Google',
    department: 'CSE',
    graduationYear: '2022',
    matchPercentage: 95,
    matchReason:
    'Strong match for software engineering, internships and career guidance.',
    about:
    'I am a software engineer passionate about helping students understand the technology industry, prepare for internships and build strong career skills.',
    canHelpWith: [
      'Career advice',
      'Internships',
      'Interview preparation',
      'Software engineering',
    ],
  ),
  AlumniData(
    name: 'Nafis Rahman',
    initials: 'NR',
    job: 'Product Designer',
    company: 'Microsoft',
    department: 'CSE',
    graduationYear: '2021',
    matchPercentage: 88,
    matchReason:
    'Good match for product design, technology careers and portfolio guidance.',
    about:
    'I work in product design and enjoy helping students understand user experience, portfolio building and careers in the technology industry.',
    canHelpWith: [
      'Product design',
      'UI/UX',
      'Portfolio',
      'Career advice',
    ],
  ),
  AlumniData(
    name: 'Ayesha Khan',
    initials: 'AK',
    job: 'Data Scientist',
    company: 'Amazon',
    department: 'CSE',
    graduationYear: '2020',
    matchPercentage: 84,
    matchReason:
    'Good match for data science, machine learning and technical career guidance.',
    about:
    'I am a data scientist interested in helping students learn about data science, machine learning and preparing for technical careers.',
    canHelpWith: [
      'Data science',
      'Machine learning',
      'Internships',
      'Interview preparation',
    ],
  ),
];
