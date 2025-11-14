<script lang="ts">
  import { onMount } from "svelte";
  import { supabase } from "../lib/supabase";
  import { Award, Calendar, BookOpen, Search, AlertCircle, TrendingUp, CheckCircle, XCircle, User, CircleCheck, CircleX, CircleAlert } from 'lucide-svelte';
  import confetti from 'canvas-confetti';

  interface Student {
    student_id: number;
    student_name: string;
    student_code: string;
    class: number;
  }

  interface Term {
    term_id: number;
    term_name: string;
  }

  interface GradeComponent {
    component_id: number;
    component_name: string;
  }

  interface GradeItem {
    item_id: number;
    class_id: number;
    component_id: number;
    title: string;
    number_of_items: number;
    term_id?: number;
  }

  interface ClassInfo {
    class_id: number;
    class_name: string;
    section: string;
    school_year: number;
    instructor: string;
  }

  let studentCodeInput = "";
  let classId = "";
  let student: Student | null = null;
  let classInfo: ClassInfo | null = null;
  let terms: Term[] = [];
  let components: GradeComponent[] = [];
  let componentGrades: Record<string, number> = {}; // `${term_id}-${component_id}` -> grade
  let termGrades: Record<number, number> = {}; // term_id -> grade
  let behaviorScores: Record<number, number> = {}; // term_id -> behavior score
  let attendanceData: Record<number, { present: number; total: number }> = {}; // term_id -> attendance data
  let componentWeights: Record<number, number> = {}; // component_id -> weight percentage
  let loading = false;
  let searching = false;
  let error = "";
  let selectedYearId: number | null = null;
  let showForm = true;
  let showConsent = true;
  let consentGiven = false;
  let realtimeChannel: any = null;
  let gradesReady = false;

  // Convert percentage grade to 1.00-3.00 scale
  function convertGradeToScale(percentage: number): string {
    if (!percentage || percentage === 0) return '-';
    if (percentage >= 99) return '1.00';
    if (percentage >= 98) return '1.10';
    if (percentage >= 97) return '1.20';
    if (percentage >= 96) return '1.25';
    if (percentage >= 95) return '1.30';
    if (percentage >= 94) return '1.40';
    if (percentage >= 93) return '1.50';
    if (percentage >= 92) return '1.60';
    if (percentage >= 91) return '1.70';
    if (percentage >= 90) return '1.75';
    if (percentage >= 89) return '1.80';
    if (percentage >= 88) return '1.90';
    if (percentage >= 87) return '2.00';
    if (percentage >= 86) return '2.10';
    if (percentage >= 85) return '2.20';
    if (percentage >= 84) return '2.25';
    if (percentage >= 83) return '2.30';
    if (percentage >= 82) return '2.40';
    if (percentage >= 81) return '2.50';
    if (percentage >= 80) return '2.60';
    if (percentage >= 79) return '2.70';
    if (percentage >= 78) return '2.75';
    if (percentage >= 77) return '2.80';
    if (percentage >= 76) return '2.90';
    if (percentage >= 75) return '3.00';
    return '5.00'; // Failed
  }

  // Get grades from database
  function getComponentGrade(termId: number, componentId: number): number {
    return componentGrades[`${termId}-${componentId}`] || 0;
  }

  function getTermGrade(termId: number): number {
    return termGrades[termId] || 0;
  }

function getFinalGrade(): number {
  if (!terms.length) return 0;
  let sum = 0;
  let count = 0;
  for (const t of terms) {
    const percentageGrade = getTermGrade(t.term_id);
    if (percentageGrade > 0) {
      sum += percentageGrade;
      count++;
    }
  }
  return count > 0 ? +(sum / count).toFixed(2) : 0;
}

  async function loadClassInfo() {
    if (!classId) return;

    loading = true;
    try {
      // Fetch class information with instructor name
      const { data: classData, error: classError } = await supabase
        .from("class")
        .select(`
          class_id, 
          class_name, 
          section, 
          school_year,
          instructor:instructor (
            instructor_name
          )
        `)
        .eq("class_id", Number(classId))
        .single();

      if (classError) {
        error = `Class not found. Error: ${classError.message}. Please make sure the class exists and the database has the required columns.`;
        loading = false;
        return;
      }

      if (!classData) {
        error = `Class with ID ${classId} not found. Please check if the class exists in your database.`;
        loading = false;
        return;
      }

      classInfo = {
        class_id: classData.class_id,
        class_name: classData.class_name,
        section: classData.section,
        school_year: classData.school_year,
        instructor: (classData as any).instructor?.instructor_name || 'N/A'
      };
      selectedYearId = classData.school_year as any;

      // Fetch terms and components
      const [termRes, compRes] = await Promise.all([
        supabase.from("term").select("term_id, term_name").order("term_id", { ascending: true }),
        supabase.from("grade_component").select("component_id, component_name").order("component_id", { ascending: true }),
      ]);

      terms = termRes.data || [];
      components = compRes.data || [];

      // Fetch component weights (store normalized 0..1 like Gradebook)
      await fetchComponentWeights();


    } catch (err) {
      error = "An error occurred while loading class information";
    }
    loading = false;
  }

  // Helper to load component weights and normalize to 0..1
  async function fetchComponentWeights() {
    try {
      const { data: weightsData } = await supabase
        .from('grade_percentage')
        .select('component, percentage');
      componentWeights = {};
      (weightsData || []).forEach((row: any) => { componentWeights[row.component] = Number(row.percentage) || 0; });
      for (const k in componentWeights) {
        if (componentWeights[k as any] > 1) componentWeights[k as any] = componentWeights[k as any] / 100;
      }
    } catch (e) {
      componentWeights = {};
    }
  }

  async function searchStudentGrade() {
    if (!studentCodeInput.trim() || !classId) {
      error = "Please enter your Student ID";
      return;
    }

    searching = true;
    error = "";
    student = null;

    try {
      // Try to fetch student by student_code first
      let { data: studentData, error: studentError } = await supabase
        .from("student")
        .select("student_id, student_name, student_code, class")
        .eq("student_code", studentCodeInput.trim())
        .eq("class", Number(classId))
        .maybeSingle();

      // If not found by student_code, try by student_id (in case student_code doesn't exist)
      if (!studentData && !studentError) {
        const studentIdNum = parseInt(studentCodeInput.trim());
        if (!isNaN(studentIdNum)) {
          const result = await supabase
            .from("student")
            .select("student_id, student_name, student_code, class")
            .eq("student_id", studentIdNum)
            .eq("class", Number(classId))
            .maybeSingle();
          studentData = result.data;
          studentError = result.error;
        }
      }

      if (studentError) {
        error = `Error: ${studentError.message}`;
        searching = false;
        return;
      }

      if (!studentData) {
        error = "Student ID not found in this class. Please check your ID and try again.";
        searching = false;
        return;
      }

      student = studentData;
      showForm = false;
      gradesReady = false;
      
      // Trigger confetti on successful login
      confetti({
        particleCount: 100,
        spread: 70,
        origin: { y: 0.6 },
        colors: ['#4CAF50', '#8BC34A', '#CDDC39', '#FFEB3B', '#FFC107']
      });

      // Fetch grades from database (what Gradebook calculated and saved)
      if (selectedYearId) {
        const { data: gradesData } = await supabase
          .from("grade")
          .select("grade_value, term_grade, grade_component")
          .eq("student_grade", studentData.student_id)
          .eq("school_year", selectedYearId);

        // If there are no precomputed grade rows, try to reconstruct averages from items
        // and item_scores and persist them back to the `grade` table so Gradebook stays in sync.
        if (!gradesData || gradesData.length === 0) {
          // Fetch items for the class
          const { data: itemsData } = await supabase
            .from('grade_component_items')
            .select('item_id,class_id,component_id,number_of_items,term_id')
            .eq('class_id', Number(classId));

          const itemsByComp: Record<number, any[]> = {};
          (itemsData || []).forEach((it: any) => {
            if (!itemsByComp[it.component_id]) itemsByComp[it.component_id] = [];
            itemsByComp[it.component_id].push(it);
          });

          const allItemIds = (itemsData || []).map((it: any) => it.item_id);

          // If no items exist, there's nothing to compute
          if (allItemIds.length === 0) {
            error = "No grades found for this student. The teacher may not have entered grades yet.";
            searching = false;
            return;
          }

          // Fetch item_scores for this student for those items
          const { data: scoresData } = await supabase
            .from('item_scores')
            .select('item_id, score')
            .eq('student_id', studentData.student_id)
            .in('item_id', allItemIds);

          const scoreByItem: Record<number, number> = {};
          (scoresData || []).forEach((s: any) => { scoreByItem[s.item_id] = Number(s.score) || 0; });

          // Build componentGrades from computed averages per component per term
          componentGrades = {};
          behaviorScores = {};
          termGrades = {};

          (components || []).forEach((comp: any) => {
            const compItems = (itemsByComp[comp.component_id] || []);
            // group items by term
            const itemsByTerm: Record<number, any[]> = {};
            compItems.forEach(it => {
              const tid = it.term_id || 0;
              if (!itemsByTerm[tid]) itemsByTerm[tid] = [];
              itemsByTerm[tid].push(it);
            });

            for (const tidStr in itemsByTerm) {
              const tid = Number(tidStr);
              const list = itemsByTerm[tid];
              if (!list || list.length === 0) continue;
              let sum = 0, count = 0;
              for (const it of list) {
                const score = scoreByItem[it.item_id] ?? 0;
                const percentage = (typeof score === 'number' && !isNaN(score) && it.number_of_items > 0) ? (score / it.number_of_items) : 0;
                const converted = (percentage * 40) + 60;
                sum += converted;
                count++;
              }
              if (count === 0) continue;
              const avg = sum / count; // 0..100
              componentGrades[`${tid}-${comp.component_id}`] = +avg.toFixed(2);
            }
          });

          // Calculate term grades from the reconstructed component grades
          recalculateTermGrades();

          // Persist computed component averages to `grade` table so Gradebook will have them
          if (selectedYearId) {
            await syncGradesToGradebook(studentData.student_id, Number(selectedYearId));
            // Refresh gradesData from server after upsert
            const { data: newGrades } = await supabase
              .from('grade')
              .select('grade_value, term_grade, grade_component')
              .eq('student_grade', studentData.student_id)
              .eq('school_year', selectedYearId);
            // populate from server response (just to be consistent)
            (newGrades || []).forEach((grade: any) => {
              componentGrades[`${grade.term_grade}-${grade.grade_component}`] = Number(grade.grade_value) || 0;
            });
          }
        } else {
          // Store component grades from database
          componentGrades = {};
          behaviorScores = {};
          termGrades = {};

          (gradesData || []).forEach((grade: any) => {
            const termId = grade.term_grade;
            const componentId = grade.grade_component;
            const gradeValue = Number(grade.grade_value) || 0;
            componentGrades[`${termId}-${componentId}`] = gradeValue;
          });

          // Recalculate term grades from the component grades
          recalculateTermGrades();
        }

        // Fetch attendance data
        const { data: attendanceRecords } = await supabase
          .from("attendance")
          .select("term_id, status")
          .eq("student_id", studentData.student_id)
          .eq("class_id", Number(classId));

        // Calculate attendance per term
        attendanceData = {};
        (attendanceRecords || []).forEach((record: any) => {
          const termId = record.term_id;
          if (!attendanceData[termId]) {
            attendanceData[termId] = { present: 0, total: 0 };
          }
          attendanceData[termId].total++;
          if (record.status === 'Present') {
            attendanceData[termId].present++;
          }
        });

        // Ensure we have the latest component weights (normalized 0..1)
        await fetchComponentWeights();

          // Calculate term grades using weights from grade_percentage
        terms.forEach(term => {
          // Get raw component scores first (before weighting)
          let componentScores = [];

          components.forEach(comp => {
            const weight = componentWeights[comp.component_id] || 0;
            const compAvg = componentGrades[`${term.term_id}-${comp.component_id}`];
            // Only include components that have actual grades
            if (typeof compAvg === 'number' && Number.isFinite(compAvg) && weight > 0 && compAvg > 0) {
              componentScores.push({
                score: compAvg,
                weight: weight
              });
            }
          });

          // Calculate attendance percentage
          const attData = attendanceData[term.term_id];
          const rawPercentage = attData ? (attData.total > 0 ? (attData.present / attData.total * 100) : 0) : 0;
          const attendancePercentage = attData ? (rawPercentage * 0.4) + 60 : 0;

          // Calculate behavior: (quiz + activity + exam + attendance) / 4 × 2.5%
          const allFactors = [...componentScores.map(c => c.score), attendancePercentage];
          const behaviorAverage = allFactors.reduce((sum, score) => sum + score, 0) / allFactors.length;
          const behaviorContribution = +(behaviorAverage * 0.025).toFixed(2);
          behaviorScores[term.term_id] = behaviorContribution;

          // Calculate component weighted scores for term grade
          const weightedScores = componentScores.map(c => c.score * c.weight);
          const totalWeightedScore = weightedScores.reduce((sum, score) => sum + score, 0);

          // Term grade = weighted components + behavior (2.5%) + attendance (2.5%)
          const finalGrade = totalWeightedScore + behaviorContribution + (attendancePercentage * 0.025);
          termGrades[term.term_id] = +finalGrade.toFixed(2);
        });

        // Set up realtime subscription for grade updates
        setupRealtimeSubscription(studentData.student_id, selectedYearId);
        gradesReady = true;
      }

    } catch (err) {
      error = "An error occurred while loading the grade";
    }

    searching = false;
  }

  function setupRealtimeSubscription(studentId: number, yearId: number) {
    // Clean up existing subscription
    if (realtimeChannel) {
      supabase.removeChannel(realtimeChannel);
    }

    // Subscribe to changes in grade, attendance, item_scores and grade_percentage
    // so the student view updates in real-time without refresh.
    realtimeChannel = supabase.channel(`student-realtime-${studentId}`);

    // Grades changes for this student
    realtimeChannel.on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'grade',
        filter: `student_grade=eq.${studentId}`
      },
      async (payload) => {
        // For simplicity re-fetch the latest grades/attendance to keep logic centralized
        await refreshGradesAndAttendance(studentId, yearId);
      }
    );

    // Attendance changes for this student
    realtimeChannel.on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'attendance',
        filter: `student_id=eq.${studentId}`
      },
      async () => {
        await refreshGradesAndAttendance(studentId, yearId);
      }
    );

    // Item scores changes for this student (in case Gradebook doesn't immediately upsert grade rows)
    realtimeChannel.on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'item_scores',
        filter: `student_id=eq.${studentId}`
      },
      async () => {
        await refreshGradesAndAttendance(studentId, yearId);
      }
    );

    // Grade percentage (weights) changes - update weights and refresh
    realtimeChannel.on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'grade_percentage'
      },
      async () => {
        // Re-fetch component weights and refresh grades/attendance
        await fetchComponentWeights();
        await refreshGradesAndAttendance(studentId, yearId);
      }
    );

    realtimeChannel.subscribe();
  }

  // Helper: refresh grades and attendance from DB and recalculate term grades
  async function refreshGradesAndAttendance(studentId: number, yearId: number) {
    try {
      // Make sure we have current component weights before recalculating
      await fetchComponentWeights();
      // Fetch latest grades
      const { data: gradesData } = await supabase
        .from('grade')
        .select('grade_value, term_grade, grade_component')
        .eq('student_grade', studentId)
        .eq('school_year', yearId);

      // Update componentGrades
      componentGrades = {};
      (gradesData || []).forEach((grade: any) => {
        componentGrades[`${grade.term_grade}-${grade.grade_component}`] = Number(grade.grade_value) || 0;
      });

      // Fetch attendance for this student
      const { data: attendanceRecords } = await supabase
        .from('attendance')
        .select('term_id, status')
        .eq('student_id', studentId)
        .eq('class_id', Number(classId));

      attendanceData = {};
      (attendanceRecords || []).forEach((record: any) => {
        const termId = record.term_id;
        if (!attendanceData[termId]) attendanceData[termId] = { present: 0, total: 0 };
        attendanceData[termId].total++;
        if (record.status === 'Present') attendanceData[termId].present++;
      });

      // Recalculate term grades using existing logic
      recalculateTermGrades();
      gradesReady = true;
    } catch (err) {
      // ignore transient errors
    }
  }

  // Sync computed componentGrades to grade table so Gradebook stays in sync
  async function syncGradesToGradebook(studentId: number, yearId: number) {
    if (!yearId) return;
    try {
      // For each computed component grade entry, upsert into grade table
      const entries: Array<any> = [];
      for (const key of Object.keys(componentGrades)) {
        const [termStr, compStr] = key.split('-');
        const termId = Number(termStr);
        const compId = Number(compStr);
        if (!termId || !compId) continue;
        const value = Number(componentGrades[key]) || 0;
        entries.push({ grade_value: value, student_grade: studentId, term_grade: termId, grade_component: compId, school_year: Number(yearId) });
      }

      // Upsert entries in batches
      for (const e of entries) {
        // Try to find existing grade row
        const { data: existing } = await supabase
          .from('grade')
          .select('grade_id')
          .eq('student_grade', e.student_grade)
          .eq('term_grade', e.term_grade)
          .eq('grade_component', e.grade_component)
          .eq('school_year', e.school_year)
          .limit(1)
          .maybeSingle();

        if (existing && (existing as any).grade_id) {
          await supabase.from('grade').update({ grade_value: e.grade_value }).eq('grade_id', (existing as any).grade_id);
        } else {
          await supabase.from('grade').insert([e]);
        }
      }
    } catch (err) {
      // swallow errors but could add debug logging behind a flag
    }
  }

  function recalculateTermGrades() {
    // Calculate term grades for each term
    terms.forEach(term => {
      // Get raw component scores first (before weighting)
      let componentScores = [];

      components.forEach(comp => {
        const weight = componentWeights[comp.component_id] || 0;
        const compAvg = componentGrades[`${term.term_id}-${comp.component_id}`];
        if (typeof compAvg === 'number' && Number.isFinite(compAvg) && weight > 0) {
          componentScores.push({
            score: compAvg,
            weight: weight
          });
        }
      });

      // Calculate attendance percentage
      let attendancePercentage = 60; // Default 60%
      const attData = attendanceData[term.term_id];
      if (attData) {
        const rawPercentage = attData.total > 0 ? (attData.present / attData.total * 100) : 100;
        attendancePercentage = (rawPercentage * 0.4) + 60;
      }

      // Calculate behavior: (quiz + activity + exam + attendance) / 4 × 2.5%
      const allFactors = [...componentScores.map(c => c.score), attendancePercentage];
      const behaviorAverage = allFactors.reduce((sum, score) => sum + score, 0) / allFactors.length;
      const behaviorContribution = +(behaviorAverage * 0.025).toFixed(2);
      behaviorScores[term.term_id] = behaviorContribution;

      // Calculate component weighted scores for term grade
      const weightedScores = componentScores.map(c => c.score * c.weight);
      const totalWeightedScore = weightedScores.reduce((sum, score) => sum + score, 0);

      // Term grade = weighted components + behavior (2.5%) + attendance (2.5%)
      const finalGrade = totalWeightedScore + behaviorContribution + (attendancePercentage * 0.025);
      termGrades[term.term_id] = +finalGrade.toFixed(2);
    });
    
    // Trigger reactivity
    termGrades = termGrades;
    behaviorScores = behaviorScores;
  }

  function resetForm() {
    // Clean up realtime subscription
    if (realtimeChannel) {
      supabase.removeChannel(realtimeChannel);
      realtimeChannel = null;
    }
    
    student = null;
    studentCodeInput = "";
    error = "";
    showForm = true;
    componentGrades = {};
    termGrades = {};
    behaviorScores = {};
    attendanceData = {};
    componentWeights = {};
  }

  onMount(() => {
    // Parse URL parameters
    const params = new URLSearchParams(window.location.hash.split('?')[1] || '');
    classId = params.get('class') || '';
    const timestamp = params.get('t') || '';
    
    // Validate link expiration (1 hour = 3600000 milliseconds)
    if (timestamp) {
      const linkTime = parseInt(timestamp, 10);
      const currentTime = Date.now();
      const oneHour = 3600000;
      
      if (currentTime - linkTime > oneHour) {
        error = "This link has expired. Please scan the QR code again to get a new link.";
        loading = false;
        return;
      }
    }
    
    if (classId) {
      loadClassInfo();
    } else {
      error = "Invalid link. Please use the QR code provided by your teacher.";
    }

    // Cleanup on unmount
    return () => {
      if (realtimeChannel) {
        supabase.removeChannel(realtimeChannel);
      }
    };
  });
</script>

<div class="min-h-screen bg-gray-50 py-8 px-4">
  <div class="max-w-6xl mx-auto">
    {#if loading}
      <div class="text-center py-20">
        <div class="animate-spin rounded-full h-16 w-16 border-b-4 border-green-600 mx-auto"></div>
        <p class="mt-4 text-gray-600 text-lg">Loading class information...</p>
      </div>
    {:else if !classInfo && error}
      <div class="bg-red-50 border-2 border-red-200 rounded-xl p-8 text-center">
        <div class="text-red-600 text-6xl mb-4">⚠️</div>
        <h2 class="text-2xl font-bold text-red-800 mb-2">Error</h2>
        <p class="text-red-700">{error}</p>
      </div>
    {:else if showConsent}
      <!-- Consent Dialog -->
      <div class="bg-white rounded-lg shadow-lg border border-gray-200 p-8 max-w-2xl mx-auto">
        <div class="text-center mb-8">
          <img src="/Group 2.png" alt="EasyGrade" class="h-12 w-auto mx-auto mb-6" />
          <h1 class="text-2xl font-bold text-gray-800 mb-4">Welcome to EasyGrade</h1>
          <p class="text-gray-600 mb-2">Before you continue, please read and agree to our terms:</p>
        </div>
        
        <div class="bg-gray-50 p-6 rounded-lg border border-gray-200 mb-8 max-h-64 overflow-y-auto">
          <h2 class="text-lg font-semibold text-gray-800 mb-4">Terms of Use</h2>
          <div class="text-sm text-gray-600">
            <ol class="list-decimal pl-5 space-y-2">
              <li>This system is for educational purposes only.</li>
              <li>Your grade information is confidential and should not be shared with others.</li>
              <li>The information displayed is for your personal reference only.</li>
              <li>Any discrepancies in grades should be reported to your instructor.</li>
              <li>We respect your privacy and handle your data in accordance with our privacy policy.</li>
            </ol>
          </div>
        </div>

        <div class="flex items-center justify-center space-x-4 mb-6">
          <input 
            type="checkbox" 
            id="consentCheckbox" 
            bind:checked={consentGiven}
            class="h-5 w-5 text-green-600 rounded border-gray-300 focus:ring-green-500"
          />
          <label for="consentCheckbox" class="text-sm font-medium text-gray-700">
            I agree to the terms and conditions
          </label>
        </div>

        <div class="flex flex-col sm:flex-row justify-center gap-4">
          <button
            onclick={() => {
              if (consentGiven) {
                showConsent = false;
                showForm = true;
              }
            }}
            class="px-6 py-3 bg-green-600 text-white font-medium rounded-lg hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
            disabled={!consentGiven}
          >
            I Agree - Continue
          </button>
          <button
            onclick={() => {
              showConsent = false;
              showForm = false;
              error = "You must agree to the terms to continue.";
            }}
            class="px-6 py-3 bg-white border border-gray-300 text-gray-700 font-medium rounded-lg hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
          >
            I Do Not Agree - Exit
          </button>
        </div>
      </div>
    {:else if showForm && classInfo}
      <!-- Student ID Input Form -->
      <div class="bg-white rounded-lg shadow border border-gray-200 p-8 max-w-md mx-auto">
        <!-- Header -->
        <div class="mb-6">
          <div class="flex flex-col items-center mb-6">
            <img src="/Group 2.png" alt="EasyGrade" class="h-10 w-auto mb-4 mt-4" />
          </div>
          <div class="flex items-center gap-3 mb-4 justify-center">
            <!-- <div class="p-3 bg-green-100 rounded-lg">
              <BookOpen class="w-8 h-8 text-green-600" />
            </div> -->
            <div>
              <h1 class="text-2xl font-bold text-green-700">
                {classInfo.class_name}
              </h1>
              {#if classInfo.section}
                <p class="text-sm text-gray-500 text-center">Section: {classInfo.section}</p>
              {/if}
            </div>
          </div>
          <p class="text-gray-600 text-center">Enter your Student ID to view your grades</p>
        </div>

        <hr class="my-6 border-gray-200" />

        <form onsubmit={(e) => { e.preventDefault(); searchStudentGrade(); }} class="max-w-md mx-auto">
          <div class="space-y-4">
            <div>
              <label for="studentId" class="block text-sm font-semibold text-gray-700 mb-2">
                Student ID
              </label>
              <input
                id="studentId"
                type="text"
                bind:value={studentCodeInput}
                placeholder="Enter your Student ID"
                class="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-green-500"
                disabled={searching}
                required
              />
              <p class="mt-1.5 text-xs text-gray-500">Enter your student code or ID number</p>
            </div>

            {#if error && !student}
              <div class="bg-red-50 border border-red-200 rounded-lg p-3 flex items-start gap-2">
                <CircleAlert class="w-4 h-4 text-red-600 mt-0.5 flex-shrink-0" />
                <p class="text-sm text-red-700">{error}</p>
              </div>
            {/if}

            <button
              type="submit"
              disabled={searching || !studentCodeInput.trim()}
              class="w-full flex items-center justify-center gap-2 px-4 py-2.5 text-sm font-semibold text-white bg-green-600 hover:bg-green-700 rounded-lg transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed mb-4"
            >
              {#if searching}
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                <span>Searching...</span>
              {:else}
                <Search class="w-4 h-4" />
                <span>View My Grades</span>
              {/if}
            </button>
          </div>
        </form>
        <p class="text-gray-500 text-center font-sans text-xs">© {classInfo.instructor} | {new Date().getFullYear()}</p>
      </div>
    {:else if student}
      <!-- Header Section with Final Grade -->
      {@const finalGrade = getFinalGrade()}
      {@const finalGradeScale = convertGradeToScale(finalGrade)}
      {@const finalPercent = finalGrade.toFixed(2)}
      <div class="bg-white rounded-lg shadow border border-gray-200 overflow-hidden mb-6">
        <div class="bg-white px-6 py-4">
          <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
            <div class="flex items-center gap-4 w-full sm:w-auto">
              {#if gradesReady}
                <img src="/EasyGrade.png" alt="EasyGrade" class="h-12 w-auto" />
                <div>
                  <h1 class="text-2xl font-bold text-green-700">
                    {student.student_name}
                  </h1>
                  <p class="text-sm text-gray-600">Student ID: {student.student_code || student.student_id}</p>
                  <div class="flex flex-wrap items-center gap-3 mt-2 text-xs text-gray-500">
                    <span class="flex items-center gap-1">
                      <BookOpen class="w-3.5 h-3.5" />
                      {classInfo?.class_name || 'N/A'}
                    </span>
                    {#if classInfo?.section}
                      <span>• {classInfo.section}</span>
                    {/if}
                    {#if classInfo?.instructor}
                      <span>• {classInfo.instructor}</span>
                    {/if}
                  </div>
                </div>
              {:else}
                <div class="h-12 w-12 bg-gray-200 rounded mr-2 animate-pulse"></div>
                <div class="flex-1 min-w-0">
                  <div class="h-6 w-48 bg-gray-200 rounded animate-pulse"></div>
                  <div class="h-4 w-40 bg-gray-200 rounded mt-2 animate-pulse"></div>
                  <div class="flex gap-2 mt-3">
                    <div class="h-4 w-20 bg-gray-200 rounded animate-pulse"></div>
                    <div class="h-4 w-24 bg-gray-200 rounded animate-pulse"></div>
                  </div>
                </div>
              {/if}
            </div>
            <div class="w-full sm:w-auto sm:text-right">
              <p class="text-sm text-green/90 font-medium mb-1">Final Grade</p>
              <div class="flex items-center sm:justify-end gap-3">
                {#if gradesReady && finalGrade > 0}
                  <div class="flex items-baseline gap-2">
                    <span class="text-3xl font-bold text-green-600">{finalGradeScale}</span>
                    <span class="text-lg text-gray-500">({finalPercent}%)</span>
                  </div>
                  {#if parseFloat(finalGradeScale) <= 3.0 && parseFloat(finalGradeScale) >= 1.0}
                    <div class="inline-flex items-center gap-1.5 px-3 py-1 bg-green-100 text-green-600 rounded-full text-xs font-semibold mt-2">
                      <CircleCheck class="w-3.5 h-3.5" />
                      PASSED
                    </div>
                  {:else if finalGradeScale === '5.00'}
                    <div class="inline-flex items-center gap-1.5 px-3 py-1 bg-red-100 text-red-600 rounded-full text-xs font-semibold mt-2">
                      <CircleX class="w-3.5 h-3.5" />
                      FAILED
                    </div>
                  {/if}
                {:else}
                  <div class="h-8 w-24 bg-gray-200 rounded animate-pulse"></div>
                {/if}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Grade Cards -->
      <div class="grid md:grid-cols-2 gap-6 mb-8">
        {#each terms.filter(t => !gradesReady || getTermGrade(t.term_id) > 0) as term}
          {@const termGrade = getTermGrade(term.term_id)}
          {@const gradeScale = convertGradeToScale(termGrade)}
          <div class="bg-white rounded-lg shadow border border-gray-200 overflow-hidden">
            <div class="bg-gray-50 border-b border-gray-200 px-6 py-4">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-3">
                  <Calendar class="w-5 h-5 text-gray-600" />
                  <h2 class="text-lg font-bold text-gray-800">{term.term_name}</h2>
                </div>
                {#if gradesReady && parseFloat(gradeScale) <= 3.0 && parseFloat(gradeScale) >= 1.0}
                  <div class="flex items-center gap-1.5 px-3 py-1 bg-green-100 text-green-700 rounded-full text-xs font-semibold">
                    <CircleCheck class="w-3.5 h-3.5" />
                    PASSED
                  </div>
                {:else if gradesReady && gradeScale === '5.00'}
                  <div class="flex items-center gap-1.5 px-3 py-1 bg-red-100 text-red-700 rounded-full text-xs font-semibold">
                    <CircleX class="w-3.5 h-3.5" />
                    FAILED
                  </div>
                {/if}
              </div>
            </div>
            <div class="p-6">
              <div class="flex items-center gap-6 mb-6">
                <div>
                  <p class="text-sm text-gray-500 mb-1">Grade</p>
                  <div class="flex items-baseline gap-2">
                    {#if gradesReady && termGrade > 0}
                      <span class="text-4xl font-bold text-gray-900">{gradeScale}</span>
                      <span class="text-lg text-gray-500">({termGrade}%)</span>
                    {:else}
                      <span class="text-4xl font-bold text-gray-900">--</span>
                      <span class="h-6 w-20 bg-gray-200 rounded animate-pulse"></span>
                    {/if}
                  </div>
                </div>
              </div>

              <!-- Component Breakdown -->
              {#if gradesReady}
              <div class="pt-6 border-t border-gray-200">
                <h3 class="text-sm font-semibold text-gray-700 mb-3 flex items-center gap-2">
                  <TrendingUp class="w-4 h-4" />
                  Grade Breakdown
                </h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                  {#each components.filter(c => c.component_id !== 4) as comp, idx}
                    {@const compAvg = getComponentGrade(term.term_id, comp.component_id) || 0}
                    {@const weight = componentWeights[comp.component_id] || 0}
                    {@const colors = [
                      { bg: 'bg-purple-50', border: 'border-purple-200', text: 'text-purple-700', textBold: 'text-purple-900' },
                      { bg: 'bg-orange-50', border: 'border-orange-200', text: 'text-orange-700', textBold: 'text-orange-900' },
                      { bg: 'bg-pink-50', border: 'border-pink-200', text: 'text-pink-700', textBold: 'text-pink-900' }
                    ]}
                    {@const color = colors[idx % colors.length]}
                    {@const actualScore = (compAvg * weight).toFixed(2)}
                    {@const weightPercent = (weight * 100).toFixed(1)}
                    <div class="{color.bg} rounded-lg p-3 border {color.border}">
                      <div class="flex justify-between items-center">
                        <span class="text-sm {color.text} font-medium">{comp.component_name}</span>
                        <span class="text-sm font-bold {color.textBold}">{actualScore}% / {weightPercent}%</span>
                      </div>
                    </div>
                  {/each}
                  
                  <!-- Behavior Score: only show if it has a non-zero value -->
                  {#if behaviorScores[term.term_id] > 0}
                    {@const behaviorScore = behaviorScores[term.term_id]}
                    <div class="bg-blue-50 rounded-lg p-3 border border-blue-200">
                      <div class="flex justify-between items-center">
                        <span class="text-sm text-blue-700 font-medium">Behavior</span>
                        <span class="text-sm font-bold text-blue-900">{behaviorScore.toFixed(2)}% / 2.5%</span>
                      </div>
                    </div>
                  {/if}
                  
                  <!-- Attendance Score -->
                  {#if true}
                    {@const attData = attendanceData[term.term_id]}
                    {@const rawPercentage = attData ? (attData.total > 0 ? (attData.present / attData.total * 100) : 0) : 0}
                    {@const adjustedPercentage = rawPercentage ? (rawPercentage * 0.4) + 60 : 0}
                    {@const attScore = (adjustedPercentage * 0.025).toFixed(2)}
                    <div class="bg-green-50 rounded-lg p-3 border border-green-200">
                      <div class="flex justify-between items-center">
                        <span class="text-sm text-green-700 font-medium">Attendance</span>
                        {#if attData}
                          <span class="text-sm font-bold text-green-900">{attScore}% / 2.5%</span>
                        {:else}
                          <div class="h-4 w-16 bg-gray-200 rounded animate-pulse"></div>
                        {/if}
                      </div>
                    </div>
                  {/if}
                </div>
              </div>
              {/if}
            </div>
          </div>
        {/each}
      </div>

      {#if gradesReady && Object.keys(termGrades).length === 0}
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6 text-center">
          <p class="text-yellow-800 font-medium">No grades available yet.</p>
          <p class="text-yellow-600 text-sm mt-2">Your teacher hasn't entered any grades for this class yet.</p>
        </div>
      {/if}

      <!-- Footer -->
      <div class="text-center mt-6 text-sm text-gray-500">
        <p>Keep up the great work! 📚</p>
      </div>
    {/if}
  </div>
</div>
