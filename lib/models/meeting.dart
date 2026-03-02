enum MeetingStatus { transcribed, inProgress, processing }

class Meeting {
  final String id;
  final String title;
  final String team;
  final String date;
  final String duration;
  final MeetingStatus status;
  final List<String> attendeeInitials;
  final String? summary;

  const Meeting({
    required this.id,
    required this.title,
    required this.team,
    required this.date,
    required this.duration,
    required this.status,
    this.attendeeInitials = const [],
    this.summary,
  });
}

// Sample data for the prototype
class SampleData {
  static const meetings = [
    Meeting(
      id: '1',
      title: 'Product Sync & Roadmap Q4',
      team: 'Product Team',
      date: 'Oct 12',
      duration: '45m 12s',
      status: MeetingStatus.transcribed,
      attendeeInitials: ['JD', 'AS', 'MK'],
      summary:
          'The team discussed the upcoming Q4 campaign launch. John presented the final creative assets, while Sarah highlighted a 15% increase in user engagement from the pilot phase.',
    ),
    Meeting(
      id: '2',
      title: 'Weekly Strategy Update',
      team: 'Leadership',
      date: 'Oct 11',
      duration: '32m 05s',
      status: MeetingStatus.transcribed,
      attendeeInitials: ['JD', 'EL'],
    ),
    Meeting(
      id: '3',
      title: 'Design Critique: Mobile App',
      team: 'Design Team',
      date: 'Oct 10',
      duration: '58m 20s',
      status: MeetingStatus.transcribed,
      attendeeInitials: ['MK', 'AS'],
    ),
    Meeting(
      id: '4',
      title: 'Client Onboarding Call',
      team: 'Marketing Team',
      date: 'Oct 9',
      duration: '42m',
      status: MeetingStatus.transcribed,
      attendeeInitials: ['JD', 'AS', 'MK'],
    ),
    Meeting(
      id: '5',
      title: 'Engineering Daily Standup',
      team: 'Platform Team',
      date: 'Oct 8',
      duration: '15m',
      status: MeetingStatus.inProgress,
      attendeeInitials: ['DC'],
    ),
    Meeting(
      id: '6',
      title: 'User Research Interview #4',
      team: 'UX Team',
      date: 'Oct 7',
      duration: '1h 05m',
      status: MeetingStatus.transcribed,
      attendeeInitials: ['MT', 'JD'],
    ),
    Meeting(
      id: '7',
      title: 'Internal Workshop: Design Systems',
      team: 'Product Design',
      date: 'Oct 6',
      duration: '2h 15m',
      status: MeetingStatus.transcribed,
      attendeeInitials: ['AS', 'MK', 'JD'],
    ),
  ];
}
