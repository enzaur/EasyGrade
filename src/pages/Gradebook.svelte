<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import { Table2, Plus, Pencil, Trash2, X, Loader, Calendar, Share2, Copy, Check, QrCode, AlertCircle, FileDown } from 'lucide-svelte';
  import { Table, TableBody, TableBodyCell, TableBodyRow, Tabs, TabItem,  Input, Button, Label } from "flowbite-svelte";
  import { supabase } from "../lib/supabase";
  import type { RealtimeChannel } from "@supabase/supabase-js";

  interface SchoolYear { school_year_id: number; school_year: string; }
  interface Class { class_id: number; class_name: string; class_code: string; section: string; schoolyear: SchoolYear | null; }
  interface Student { student_id: number; student_name: string; student_code: string; class_id: number; class?: Class | null; }
  interface Term { term_id: number; term_name: string; }
  interface GradeComponent { component_id: number; component_name: string; }
  interface GradeItem { item_id: number; class_id: number; component_id: number; title: string; number_of_items: number; created_at?: string; term_id?: number; }
  interface GradeRow { grade_id: number; grade_value: number; student_grade: number; term_grade: number; grade_component: number; school_year: number; }
  interface ItemScore { score_id?: number; student_id: number; item_id: number; score: number; }
  interface AttendanceRecord { attendance_id?: number; student_id: number; term_id: number; school_year_id: number; attendance_percentage: number; }

  let schoolYears: SchoolYear[] = [];
  let classes: Class[] = [];
  let students: Student[] = [];
  let terms: Term[] = [];
  let components: GradeComponent[] = [];
  let itemsByComponent: Record<number, GradeItem[]> = {};
  let gradesMap: Map<string, GradeRow> = new Map(); // key: `${student_id}-${term_id}-${component_id}-${school_year_id}`

  let search = "";
  let selectedYearId: number | "" = "";
  let selectedClassId: number | "" = "";

  let loadingStudents = false;
  let loadingGrid = false;

  // client-side per-item scores (not persisted individually)
  let itemScores: Record<string, number> = {}; // key `${student}-${term}-${component}-${item_id}`

  // Attendance records per student - stores which dates they were present
  let attendanceRecords: Record<string, Set<string>> = {}; // key `${student_id}-${term_id}` -> Set of dates (YYYY-MM-DD)
  let attendancePercentages: Record<string, number> = {}; // key `${student_id}-${term_id}-${school_year_id}` -> percentage
  let attendanceDates: Record<number, string[]> = {}; // key: term_id -> List of dates to show as columns (YYYY-MM-DD)
  
  // Reactivity trigger for real-time calculations
  let updateTrigger = 0;

  // fallback weights if grade_percentage table empty
  let componentWeights: Record<number, number> = {}; // component_id -> 0..1

  // Add item modal state
  let showAddItemModal = false;
  let newItemTitle = "";
  let newItemMaxScore = 0;
  let selectedComponentId: number | "" = "";
  let selectedTermId: number | "" = "";
  let addingItem = false;

  // Edit item modal state
  let showEditItemModal = false;
  let editingItem: GradeItem | null = null;
  let editItemTitle = "";
  let editItemMaxScore = 100;
  let editItemDate = "";
  let updatingItem = false;

  // Add attendance date modal state
  let showAddAttendanceModal = false;
  let newAttendanceDate = "";
  let selectedTermIdForAttendance: number | "" = "";
  let addingAttendance = false;

  // Edit attendance modal state
  let showEditAttendanceModal = false;
  let editingAttendanceDate = "";
  let editingTermId: number | "" = "";
  let originalAttendanceDate = "";
  let updatingAttendance = false;

  // Realtime channels
  let itemScoresChannel: RealtimeChannel | null = null;
  let itemsChannel: RealtimeChannel | null = null;
  let attendanceChannel: RealtimeChannel | null = null;

  // Tab persistence
  let activeTabIndex = 0;

  // Share link state
  let showShareModal = false;
  let shareLink = "";
  let copiedLink = false;
  let qrCodeDataUrl = "";

  // PDF export state
  let exportingPDF = false;

  function keyGrade(s: number, t: number, c: number, y: number) { return `${s}-${t}-${c}-${y}`; }
  function keyItem(s: number, t: number, c: number, itemId: number) { return `${s}-${t}-${c}-${itemId}`; }
  function keyAttendance(s: number, t: number, y: number) { return `${s}-${t}-${y}`; }

  // Generate class share link
  async function openShareModal() {
    if (!selectedClassId) return;
    const baseUrl = window.location.origin + window.location.pathname;
    const timestamp = Date.now(); // Add timestamp for expiration
    const link = `${baseUrl}#/student-grade?class=${selectedClassId}&t=${timestamp}`;
    shareLink = link;
    showShareModal = true;
    copiedLink = false;
    
    // Generate QR code
    await generateQRCode(link);
  }

  // Generate QR code using QRCode.js library via CDN
  async function generateQRCode(text: string) {
    try {
      // Create a canvas element
      const canvas = document.createElement('canvas');
      const size = 256;
      canvas.width = size;
      canvas.height = size;
      const ctx = canvas.getContext('2d');
      
      if (!ctx) return;
      
      // Use a simple QR code API service
      const qrApiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=${size}x${size}&data=${encodeURIComponent(text)}`;
      
      // Load the QR code image
      const img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = () => {
        ctx.drawImage(img, 0, 0, size, size);
        qrCodeDataUrl = canvas.toDataURL('image/png');
      };
      img.src = qrApiUrl;
    } catch (error) {
      // QR code generation failed
    }
  }

  // Download QR code
  function downloadQRCode() {
    if (!qrCodeDataUrl) return;
    const link = document.createElement('a');
    const selectedClass = classes.find(c => c.class_id === Number(selectedClassId));
    const fileName = selectedClass ? `${selectedClass.class_name}_QR.png` : 'class_qr_code.png';
    link.download = fileName;
    link.href = qrCodeDataUrl;
    link.click();
  }

  // Copy share link to clipboard
  async function copyClassShareLink() {
    try {
      await navigator.clipboard.writeText(shareLink);
      copiedLink = true;
      setTimeout(() => {
        copiedLink = false;
      }, 2000);
    } catch (err) {
      alert('Failed to copy link. Please copy it manually.');
    }
  }

  // Load itemScores from localStorage on component init
  function loadItemScoresFromStorage() {
    // No longer using localStorage - data comes from database
  }

  // Save itemScores to localStorage
  function saveItemScoresToStorage() {
    // No longer using localStorage - data is saved to database
  }

  // Load active tab from localStorage
  function loadActiveTabFromStorage() {
    try {
      const stored = localStorage.getItem('gradebook_activeTab');
      if (stored) {
        activeTabIndex = parseInt(stored, 10);
      }
    } catch (error) {
      // Failed to load tab from storage
    }
  }

  // Save active tab to localStorage
  function saveActiveTabToStorage(index: number) {
    try {
      localStorage.setItem('gradebook_activeTab', index.toString());
      activeTabIndex = index;
    } catch (error) {
      // Failed to save tab to storage
    }
  }
  
  function formatDate(dateStr?: string): string {
    if (!dateStr) return '-';
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  }

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

  // Check if grade is passing (< 5.00 or >= 75%)
  function isPassingGrade(percentage: number): boolean {
    if (!percentage || percentage === 0) return false;
    return percentage >= 75;
  }

  // Get color class for grade
  function getGradeColorClass(percentage: number): string {
    if (!percentage || percentage === 0) return 'text-gray-700';
    return isPassingGrade(percentage) ? 'text-green-600' : 'text-red-600';
  }

  async function fetchSchoolYears() {
    const { data } = await supabase.from("schoolyear").select("school_year_id, school_year").order("school_year", { ascending: true });
    schoolYears = data || [];
  }

  async function fetchClasses() {
    const { data } = await supabase
      .from("class")
      .select(`class_id,class_name,class_code,section,schoolyear:school_year (school_year_id, school_year)`).filter("is_archived","eq", false)
      .order("class_name", { ascending: true });
    classes = (data || []).map((c: any) => ({ ...c, schoolyear: c.schoolyear?.[0] || null }));
  }

  async function fetchStudents() {
    loadingStudents = true;
    const { data } = await supabase
      .from("student")
      .select(`student_id, student_name, student_code, class:class!inner ( class_id, class_name, class_code, section, is_archived )`)
      .eq("class.is_archived", false)
      .order("student_name", { ascending: true });
    students = (data || []).map((s: any) => ({ student_id: s.student_id, student_name: s.student_name, student_code: s.student_code, class_id: s.class?.class_id || 0, class: s.class }));
    loadingStudents = false;
  }

  async function fetchTermsAndComponents() {
    const [termRes, compRes] = await Promise.all([
      supabase.from("term").select("term_id, term_name").order("term_id", { ascending: true }),
      supabase.from("grade_component").select("component_id, component_name").order("component_id", { ascending: true }),
    ]);
    terms = termRes.data || [];
    components = compRes.data || [];
  }

  async function fetchComponentWeights() {
    const { data } = await supabase.from("grade_percentage").select("percentage, component");
    componentWeights = {};
    (data || []).forEach((row: any) => { componentWeights[row.component] = row.percentage; });
    // Normalize to 0..1 if user stored as 0..100
    for (const k in componentWeights) {
      if (componentWeights[k as any] > 1) componentWeights[k as any] = componentWeights[k as any] / 100;
    }
  }

  async function fetchItemsForClass(classId: number) {
    const { data } = await supabase
      .from("grade_component_items")
      .select("item_id,class_id,component_id,title,number_of_items,created_at,term_id")
      .eq("class_id", classId)
      .order("item_id", { ascending: true });
    itemsByComponent = {};
    (data || []).forEach((it: GradeItem) => {
      if (!itemsByComponent[it.component_id]) itemsByComponent[it.component_id] = [];
      itemsByComponent[it.component_id].push(it);
    });
  }

  async function fetchExistingGrades(classId: number, yearId: number) {
    // get students of class
    const studentIds = filteredStudents.filter(s => s.class_id === classId).map(s => s.student_id);
    if (studentIds.length === 0) { gradesMap = new Map(); return; }
    const { data } = await supabase
      .from("grade")
      .select("grade_id,grade_value,student_grade,term_grade,grade_component,school_year")
      .in("student_grade", studentIds)
      .eq("school_year", yearId);
    gradesMap = new Map();
    (data || []).forEach((g: GradeRow) => {
      gradesMap.set(keyGrade(g.student_grade, g.term_grade, g.grade_component, g.school_year), g);
    });
  }

  async function fetchItemScores(classId: number) {
    // Get all items for this class
    const allItems = Object.values(itemsByComponent).flat();
    const itemIds = allItems.map(it => it.item_id);
    if (itemIds.length === 0) return;

    // Get students of class
    const studentIds = filteredStudents.filter(s => s.class_id === classId).map(s => s.student_id);
    if (studentIds.length === 0) return;

    // Fetch all item scores for these students and items
    const { data } = await supabase
      .from("item_scores")
      .select("student_id, item_id, score")
      .in("student_id", studentIds)
      .in("item_id", itemIds);

    // Create a new object to preserve existing data
    const newItemScores = { ...itemScores };
    
    // Only update scores for this class, preserve others
    (data || []).forEach((row: any) => {
      // Find the item to get its component and term
      const item = allItems.find(it => it.item_id === row.item_id);
      if (item) {
        const key = keyItem(row.student_id, item.term_id || 0, item.component_id, row.item_id);
        newItemScores[key] = row.score;
      }
    });
    
    // Update the state with the new object
    itemScores = newItemScores;
  }

  async function fetchAttendance(classId: number, yearId: number) {
    const studentIds = filteredStudents.filter(s => s.class_id === classId).map(s => s.student_id);
    if (studentIds.length === 0) return;

    const { data } = await supabase
      .from("attendance")
      .select("student_id, attendance_date, status, term_id")
      .eq("class_id", classId)
      .in("student_id", studentIds)
      .order("attendance_date", { ascending: true });

    // Reset attendance records
    attendanceRecords = {};
    attendancePercentages = {};
    attendanceDates = {};
    const datesByTerm: Record<number, Set<string>> = {};

    // Build attendance records per student per term
    const studentAttendanceByTerm: Record<string, { present: number; total: number }> = {};
    
    (data || []).forEach((record: any) => {
      const studentId = record.student_id;
      const dateStr = record.attendance_date;
      const termId = record.term_id;
      
      if (!termId) return; // Skip records without term_id
      
      // Track dates by term
      if (!datesByTerm[termId]) {
        datesByTerm[termId] = new Set();
      }
      datesByTerm[termId].add(dateStr);
      
      // Track attendance per student per term
      const studentTermKey = `${studentId}-${termId}`;
      if (!attendanceRecords[studentTermKey]) {
        attendanceRecords[studentTermKey] = new Set();
      }
      if (!studentAttendanceByTerm[studentTermKey]) {
        studentAttendanceByTerm[studentTermKey] = { present: 0, total: 0 };
      }
      
      studentAttendanceByTerm[studentTermKey].total++;
      if (record.status === 'Present') {
        attendanceRecords[studentTermKey].add(dateStr);
        studentAttendanceByTerm[studentTermKey].present++;
      }
    });

    // Get last 10 dates per term or generate dates for current month
    for (const term of terms) {
      const termDates = datesByTerm[term.term_id];
      const sortedDates = termDates ? Array.from(termDates).sort() : [];
      attendanceDates[term.term_id] = sortedDates.length > 0 ? sortedDates.slice(-10) : [];
    }

    // Calculate percentages for each student per term
    for (const term of terms) {
      for (const studentId of studentIds) {
        const studentTermKey = `${studentId}-${term.term_id}`;
        const key = keyAttendance(studentId, term.term_id, yearId);
        const attendance = studentAttendanceByTerm[studentTermKey];
        if (attendance && attendance.total > 0) {
          // Calculate actual attendance percentage, then apply the formula:
          // (actual% × 0.4 + 60) to get adjusted percentage
          const actualPercentage = (attendance.present / attendance.total) * 100;
          attendancePercentages[key] = (actualPercentage * 0.4) + 60;
        } else {
          // If no attendance data, use base score of 60%
          attendancePercentages[key] = 60;
        }
      }
    }
  }

  function generateRecentDates(count: number): string[] {
    const dates: string[] = [];
    const today = new Date();
    for (let i = count - 1; i >= 0; i--) {
      const date = new Date(today);
      date.setDate(date.getDate() - i);
      dates.push(date.toISOString().split('T')[0]);
    }
    return dates;
  }

  async function toggleAttendance(studentId: number, termId: number, date: string, isPresent: boolean) {
    if (!selectedClassId || !selectedYearId) return;

    const classId = Number(selectedClassId);
    const status = isPresent ? 'Present' : 'Absent';

    try {
      // Check if record exists for this date and term
      const { data: existing } = await supabase
        .from("attendance")
        .select("attendance_id")
        .eq("class_id", classId)
        .eq("student_id", studentId)
        .eq("attendance_date", date)
        .eq("term_id", termId)
        .maybeSingle();

      if (existing) {
        // Update existing record
        await supabase
          .from("attendance")
          .update({ status })
          .eq("attendance_id", existing.attendance_id);
      } else {
        // Insert new record
        await supabase
          .from("attendance")
          .insert([{
            class_id: classId,
            student_id: studentId,
            attendance_date: date,
            term_id: termId,
            status
          }]);
      }

      // Update local state immediately for responsiveness
      const studentTermKey = `${studentId}-${termId}`;
      if (!attendanceRecords[studentTermKey]) {
        attendanceRecords[studentTermKey] = new Set();
      }
      if (isPresent) {
        attendanceRecords[studentTermKey].add(date);
      } else {
        attendanceRecords[studentTermKey].delete(date);
      }
      attendanceRecords = attendanceRecords; // Trigger reactivity
      updateTrigger++; // Increment to force grade recalculation

      // Refresh attendance data in background
      await fetchAttendance(classId, Number(selectedYearId));
    } catch (error) {
      // Failed to toggle attendance
    }
  }

  function setupRealtimeSubscriptions() {
    // Cleanup existing channels
    if (itemScoresChannel) supabase.removeChannel(itemScoresChannel);
    if (itemsChannel) supabase.removeChannel(itemsChannel);
    if (attendanceChannel) supabase.removeChannel(attendanceChannel);

    // Subscribe to item_scores changes
    itemScoresChannel = supabase
      .channel('item-scores-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'item_scores' },
        (payload) => {
          if (payload.eventType === 'INSERT' || payload.eventType === 'UPDATE') {
            const record = payload.new as any;
            // Find the item to get component and term info
            const allItems = Object.values(itemsByComponent).flat();
            const item = allItems.find(it => it.item_id === record.item_id);
            if (item) {
              const key = keyItem(record.student_id, item.term_id || 0, item.component_id, record.item_id);
              itemScores[key] = record.score;
              itemScores = itemScores; // Trigger reactivity
              
              // Force reactivity for computed averages by creating a new object
              setTimeout(() => {
                itemScores = { ...itemScores };
              }, 0);
            }
          }
        }
      )
      .subscribe();

    // Subscribe to grade_component_items changes
    itemsChannel = supabase
      .channel('items-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'grade_component_items' },
        async () => {
          if (selectedClassId) {
            await fetchItemsForClass(Number(selectedClassId));
          }
        }
      )
      .subscribe();

    // Subscribe to attendance changes
    attendanceChannel = supabase
      .channel('attendance-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'attendance' },
        async () => {
          if (selectedClassId && selectedYearId) {
            await fetchAttendance(Number(selectedClassId), Number(selectedYearId));
          }
        }
      )
      .subscribe();
  }

  onMount(async () => {
    // Load persisted data first
    loadItemScoresFromStorage();
    loadActiveTabFromStorage();
    await Promise.all([fetchSchoolYears(), fetchClasses(), fetchStudents(), fetchTermsAndComponents(), fetchComponentWeights()]);
    setupRealtimeSubscriptions();
  });

  onDestroy(() => {
    if (itemScoresChannel) supabase.removeChannel(itemScoresChannel);
    if (itemsChannel) supabase.removeChannel(itemsChannel);
    if (attendanceChannel) supabase.removeChannel(attendanceChannel);
  });

  $: filteredStudents = students.filter((student) =>
    (!search || student.student_name.toLowerCase().includes(search.toLowerCase())) &&
    (!selectedClassId || student.class_id === Number(selectedClassId))
  );

  // Force reactivity for computed averages when itemScores change
  $: {
    // This reactive statement ensures component averages update in realtime
    const _ = itemScores;
    // No action needed - just triggers reactivity for computed functions
  }

  // load grid data when class & year selected
  $: if (selectedClassId && selectedYearId) {
    (async () => {
      loadingGrid = true;
      await fetchItemsForClass(Number(selectedClassId));
      await fetchItemScores(Number(selectedClassId));
      await fetchExistingGrades(Number(selectedClassId), Number(selectedYearId));
      await fetchAttendance(Number(selectedClassId), Number(selectedYearId));
      loadingGrid = false;
    })();
  }

  // Compute component percentage (total score / total possible score * component weight)
  function computeComponentPercentage(studentId: number, termId: number, componentId: number): number {
    // Get items for this component and term
    const allItems = itemsByComponent[componentId] || [];
    const items = allItems.filter(it => !it.term_id || it.term_id === termId);
    
    if (items.length === 0) return 0;
    
    let sum = 0;
    let count = 0;
    
    for (const it of items) {
      const score = itemScores[keyItem(studentId, termId, componentId, it.item_id)];
      // Apply formula: ((score / number_of_items) * 40) + 60
      // If score is 0 or undefined, it will result in 60%
      const scoreValue = (typeof score === 'number' && !isNaN(score) && score >= 0) ? score : 0;
      const percentage = scoreValue / it.number_of_items;
      const converted = (percentage * 40) + 60;
      sum += converted;
      count++;
    }
    
    if (count === 0) return 0;
    
    // Calculate average of all converted scores
    const average = sum / count;
    
    // Get component weight from grade_percentage table (already normalized to 0..1)
    const componentWeight = componentWeights[componentId] || 0;
    
    // Return percentage weighted by component weight
    return +((average / 100) * componentWeight * 100).toFixed(2);
  }

  // Helpers to compute component average using formula: ((score/max_items)*40 + 60)
  function computeComponentAverage(studentId: number, termId: number, componentId: number): number {
    // Get items for this component and term
    const allItems = itemsByComponent[componentId] || [];
    const items = allItems.filter(it => !it.term_id || it.term_id === termId);
    
    if (items.length === 0) {
      // fall back to stored grade if exists
      const g = gradesMap.get(keyGrade(studentId, termId, componentId, Number(selectedYearId)));
      return g ? g.grade_value : 0;
    }
    
    let sum = 0, count = 0;
    for (const it of items) {
      const score = itemScores[keyItem(studentId, termId, componentId, it.item_id)];
      // Apply formula: ((score / number_of_items) * 40) + 60
      // If score is 0 or undefined, it will result in 60%
      const scoreValue = (typeof score === 'number' && !isNaN(score) && score >= 0) ? score : 0;
      const percentage = scoreValue / it.number_of_items;
      const converted = (percentage * 40) + 60;
      sum += converted;
      count++;
    }
    
    if (count === 0) return 0;
    // Return average of all converted scores
    return +(sum / count).toFixed(2);
  }

  // Compute behavior percentage (quiz + activity + exam + attendance) / 4 × 2.5%
  function computeBehaviorPercentage(studentId: number, termId: number): number {
    let componentTotal = 0;
    let componentCount = 0;

    // Sum up component averages
    for (const comp of components) {
      const allItems = itemsByComponent[comp.component_id] || [];
      const items = allItems.filter(it => !it.term_id || it.term_id === termId);
      if (items.length === 0) continue;
      
      const avg = computeComponentAverage(studentId, termId, comp.component_id);
      componentTotal += avg;
      componentCount++;
    }

    // Get attendance percentage
    const attendanceKey = keyAttendance(studentId, termId, Number(selectedYearId));
    const attendancePercentage = attendancePercentages[attendanceKey] || 60; // Default 60%
    
    // Only calculate if we have components
    if (componentCount === 0) return 0;
    
    // Calculate (quiz + activity + exam + attendance) / 4 × 2.5%
    const sumOfAllFactors = componentTotal + attendancePercentage;
    const averageOfFactors = sumOfAllFactors / (componentCount + 1); // +1 for attendance
    return +(averageOfFactors * 0.025).toFixed(2);
  }

  function computeTermAverage(studentId: number, termId: number): number {
    // Sum up each component's weighted contribution based on its weight
    let totalWeightedScore = 0;
    let totalWeight = 0;

    // Calculate weighted component scores (Quiz, Activity, Exam)
    for (const comp of components) {
      const weight = componentWeights[comp.component_id] || 0;
      if (weight > 0) {
        const avg = computeComponentAverage(studentId, termId, comp.component_id);
        totalWeightedScore += avg * weight;
        totalWeight += weight;
      }
    }

    // Get behavior contribution (quiz + activity + exam + attendance) / 4 × 2.5%
    const behaviorContribution = computeBehaviorPercentage(studentId, termId);
    
    // Get attendance contribution (2.50% weight)
    const attendanceKey = keyAttendance(studentId, termId, Number(selectedYearId));
    const attendancePercentage = attendancePercentages[attendanceKey] || 60; // Use 60% if not set
    const attendanceContribution = attendancePercentage * 0.025; // 2.50% weight
    
    // Total should be component scores + behavior contribution + attendance contribution
    const total = totalWeightedScore + behaviorContribution + attendanceContribution;
    return +total.toFixed(2);
    
    
  }

  function computeFinalAverage(studentId: number): number {
    if (!terms.length) return 0;
    let sum = 0;
    for (const t of terms) sum += computeTermAverage(studentId, t.term_id);
    return +(sum / terms.length).toFixed(2);
  }

  async function upsertGrade(studentId: number, termId: number, componentId: number, value: number) {
    if (!selectedYearId) return;
    const payload = { grade_value: value, student_grade: studentId, term_grade: termId, grade_component: componentId, school_year: Number(selectedYearId) };
    // check existing
    const k = keyGrade(studentId, termId, componentId, Number(selectedYearId));
    const existing = gradesMap.get(k);
    if (existing) {
      const { data, error } = await supabase.from("grade").update({ grade_value: value }).eq("grade_id", existing.grade_id).select().single();
      if (!error && data) gradesMap.set(k, data as any);
    } else {
      const { data, error } = await supabase.from("grade").insert([payload]).select().single();
      if (!error && data) gradesMap.set(k, data as any);
    }
  }

  // Debounce timer for database saves
  let saveTimers: Record<string, any> = {};

  // handle change in any item cell - autosave to database
  async function onItemChange(studentId: number, termId: number, componentId: number, itemId: number, ev: Event) {
    const val = Number((ev.target as HTMLInputElement).value);
    const score = isNaN(val) || val < 0 ? 0 : val;
    
    // Update local state immediately
    itemScores[keyItem(studentId, termId, componentId, itemId)] = score;
    // Trigger reactivity by reassigning
    itemScores = itemScores;
    updateTrigger++; // Increment to force reactivity
    
    // Debounce database save (wait 500ms after last keystroke)
    const saveKey = `${studentId}-${itemId}`;
    if (saveTimers[saveKey]) {
      clearTimeout(saveTimers[saveKey]);
    }
    
    saveTimers[saveKey] = setTimeout(async () => {
      // Autosave to database using upsert (on conflict update)
      try {
        await supabase
          .from("item_scores")
          .upsert(
            { student_id: studentId, item_id: itemId, score, updated_at: new Date().toISOString() },
            { onConflict: 'student_id,item_id' }
          );
        
        // Also update component average in grade table
        const compAvg = computeComponentAverage(studentId, termId, componentId);
        await upsertGrade(studentId, termId, componentId, compAvg);
      } catch (error) {
        // Failed to save score
      }
    }, 500); // Wait 500ms after last keystroke
  }

  // simple pagination for students
  let currentPage = 1;
  let itemsPerPage = 10;
  $: totalPages = Math.ceil(filteredStudents.length / itemsPerPage) || 1;
  $: startIndex = (currentPage - 1) * itemsPerPage;
  $: endIndex = startIndex + itemsPerPage;
  $: paginatedStudents = filteredStudents.slice(startIndex, endIndex);
  $: if (search || selectedYearId || selectedClassId) currentPage = 1;

  function openAddItemModal() {
    if (!selectedClassId) {
      alert("Please select a class first");
      return;
    }
    showAddItemModal = true;
    newItemTitle = "";
    newItemMaxScore = 0;
    selectedComponentId = "";
    selectedTermId = "";
  }

  async function addNewItem() {
    if (!newItemTitle.trim() || !selectedComponentId || !selectedClassId || !selectedTermId) {
      alert("Please fill in all fields");
      return;
    }
    addingItem = true;
    const { data, error } = await supabase
      .from("grade_component_items")
      .insert([{
        class_id: Number(selectedClassId),
        component_id: Number(selectedComponentId),
        title: newItemTitle.trim(),
        number_of_items: newItemMaxScore,
        term_id: Number(selectedTermId)
      }])
      .select()
      .single();
    
    if (error) {
      alert("Failed to add item");
    } else {
      // Refresh items
      await fetchItemsForClass(Number(selectedClassId));
      showAddItemModal = false;
    }
    addingItem = false;
  }

  function openEditItemModal(item: GradeItem) {
    editingItem = item;
    editItemTitle = item.title;
    editItemMaxScore = item.number_of_items;
    editItemDate = item.created_at ? new Date(item.created_at).toISOString().split('T')[0] : "";
    showEditItemModal = true;
  }

  async function updateItem() {
    if (!editingItem || !editItemTitle.trim()) {
      alert("Please fill in all fields");
      return;
    }
    updatingItem = true;
    const updateData: any = {
      title: editItemTitle.trim(),
      number_of_items: editItemMaxScore
    };
    if (editItemDate) {
      updateData.created_at = new Date(editItemDate).toISOString();
    }
    
    const { error } = await supabase
      .from("grade_component_items")
      .update(updateData)
      .eq("item_id", editingItem.item_id);
    
    if (error) {
      alert("Failed to update item");
    } else {
      await fetchItemsForClass(Number(selectedClassId));
      showEditItemModal = false;
      editingItem = null;
    }
    updatingItem = false;
  }

  async function deleteItem(itemId: number) {
    if (!confirm("Are you sure you want to delete this item? This will also delete all associated grades.")) {
      return;
    }
    
    const { error } = await supabase
      .from("grade_component_items")
      .delete()
      .eq("item_id", itemId);
    
    if (error) {
      alert("Failed to delete item");
    } else {
      await fetchItemsForClass(Number(selectedClassId));
    }
  }

  function openAddAttendanceModal() {
    if (!selectedClassId) {
      alert("Please select a class first");
      return;
    }
    showAddAttendanceModal = true;
    newAttendanceDate = new Date().toISOString().split('T')[0]; // Default to today
    selectedTermIdForAttendance = ""; // Reset term selection
  }

// Export to PDF function
async function exportToPDF() {
  if (!selectedClassId || !selectedYearId) {
    alert("Please select a class and school year first");
    return;
  }

  exportingPDF = true;

  try {
    // Dynamically import jsPDF and autoTable
    const { default: jsPDF } = await import('jspdf');
    const { default: autoTable } = await import('jspdf-autotable');

    const doc = new jsPDF('l', 'mm', 'a4'); // Landscape orientation
    const pageWidth = doc.internal.pageSize.getWidth();
    const pageHeight = doc.internal.pageSize.getHeight();

    // Load and add header image
    const img = new Image();
    img.src = '/Group 2.png';
    await new Promise((resolve) => {
      img.onload = resolve;
      img.onerror = resolve; // Continue even if image fails to load
    });

    // Add header image (centered, preserving aspect ratio)
    const maxWidth = 80;
    const maxHeight = 15;
    const naturalWidth = img.naturalWidth;
    const naturalHeight = img.naturalHeight;

    if (naturalWidth > 0 && naturalHeight > 0) {
      // Calculate scale to fit within max dimensions without distortion
      const scaleX = maxWidth / naturalWidth;
      const scaleY = maxHeight / naturalHeight;
      const scale = Math.min(scaleX, scaleY); // Use the smaller scale to fit inside the box
      
      const imgWidth = naturalWidth * scale;
      const imgHeight = naturalHeight * scale;
      
      const imgX = (pageWidth - imgWidth) / 2;
      doc.addImage(img, 'PNG', imgX, 10, imgWidth, imgHeight);
    } else {
      // Fallback if image dimensions can't be read (e.g., load error)
      console.warn('Image dimensions unavailable; skipping header image.');
    }

    // Get selected class info
    const selectedClass = classes.find(c => c.class_id === Number(selectedClassId));
    const selectedYear = schoolYears.find(y => y.school_year_id === Number(selectedYearId));
    
    // Add class and year info
    doc.setFontSize(12);
    doc.setFont('helvetica', 'bold');
    const classInfo = `${selectedClass?.class_name || ''} - ${selectedClass?.section || ''}`;
    const yearInfo = `School Year: ${selectedYear?.school_year || ''}`;
    doc.text(classInfo, pageWidth / 2, 32, { align: 'center' });
    doc.text(yearInfo, pageWidth / 2, 38, { align: 'center' });

    // Determine active components (those with non-zero average for at least one student)
    const activeComponents = components.filter(comp => {
      return filteredStudents.some(student => {
        let totalPercentage = 0;
        let termCount = 0;
        for (const term of terms) {
          const percentage = computeComponentPercentage(student.student_id, term.term_id, comp.component_id);
          if (percentage > 0) {
            totalPercentage += percentage;
            termCount++;
          }
        }
        const avgPercentage = termCount > 0 ? totalPercentage / termCount : 0;
        return avgPercentage > 0;
      });
    });

    // Prepare table data
    const tableHeaders = [
      'No',
      'Student ID',
      'Student Name'
    ];

    // Add component headers with percentages for active components only
    for (const comp of activeComponents) {
      const weight = componentWeights[comp.component_id] || 0;
      const weightPercent = (weight * 100).toFixed(1);
      tableHeaders.push(`${comp.component_name}\n(${weightPercent}%)`);
    }
    tableHeaders.push('Behavior\n(2.5%)');
    tableHeaders.push('Attendance\n(2.5%)');
    
    // Add term columns
    for (const term of terms) {
      tableHeaders.push(term.term_name);
    }
    tableHeaders.push('Final Grade');

    // Prepare table rows
    const tableRows = filteredStudents.map((student, idx) => {
      const row = [
        (idx + 1).toString(),
        student.student_code,
        student.student_name
      ];

      // Calculate component percentages (average across all terms) for active components only
      for (const comp of activeComponents) {
        let totalPercentage = 0;
        let termCount = 0;
        for (const term of terms) {
          const percentage = computeComponentPercentage(student.student_id, term.term_id, comp.component_id);
          if (percentage > 0) {
            totalPercentage += percentage;
            termCount++;
          }
        }
        const avgPercentage = termCount > 0 ? (totalPercentage / termCount).toFixed(2) : '0.00';
        row.push(`${avgPercentage}%`);
      }

      // Calculate behavior percentage (average across all terms)
      let totalBehavior = 0;
      let behaviorCount = 0;
      for (const term of terms) {
        const behavior = computeBehaviorPercentage(student.student_id, term.term_id);
        if (behavior > 0) {
          totalBehavior += behavior;
          behaviorCount++;
        }
      }
      const avgBehavior = behaviorCount > 0 ? (totalBehavior / behaviorCount).toFixed(2) : '0.00';
      row.push(`${avgBehavior}%`);

      // Calculate attendance percentage (average across all terms)
      let totalAttendance = 0;
      let attendanceCount = 0;
      for (const term of terms) {
        const attendanceKey = keyAttendance(student.student_id, term.term_id, Number(selectedYearId));
        const attendancePercentage = attendancePercentages[attendanceKey] ?? 100;
        const attendanceScore = attendancePercentage * 0.025;
        if (attendanceScore > 0) {
          totalAttendance += attendanceScore;
          attendanceCount++;
        }
      }
      const avgAttendance = attendanceCount > 0 ? (totalAttendance / attendanceCount).toFixed(2) : '0.00';
      row.push(`${avgAttendance}%`);

      // Add term grades
      for (const term of terms) {
        const termAvg = computeTermAverage(student.student_id, term.term_id);
        row.push(convertGradeToScale(termAvg));
      }

      // Add final grade
      const finalAvg = computeFinalAverage(student.student_id);
      row.push(convertGradeToScale(finalAvg));

      return row;
    });

    // Generate table
    autoTable(doc, {
      head: [tableHeaders],
      body: tableRows,
      startY: 45,
      theme: 'grid',
      styles: {
        fontSize: 8,
        cellPadding: 2,
        halign: 'center',
        valign: 'middle'
      },
      headStyles: {
        fillColor: [34, 197, 94], // Green color
        textColor: 255,
        fontStyle: 'bold',
        halign: 'center'
      },
      columnStyles: {
        0: { cellWidth: 10 }, // No
        1: { cellWidth: 20 }, // Student ID
        2: { cellWidth: 40, halign: 'left' } // Student Name
      },
      margin: { top: 45, bottom: 20 },
      didDrawPage: function(data) {
        // Add footer on each page
        const currentYear = new Date().getFullYear();
        doc.setFontSize(9);
        doc.setFont('helvetica', 'normal');
        doc.text(
          `© L. Pantalla ${currentYear}`,
          pageWidth / 2,
          pageHeight - 10,
          { align: 'center' }
        );
      }
    });

    // Save the PDF
    const fileName = `Gradebook_${selectedClass?.class_name || 'Class'}_${selectedYear?.school_year || 'Year'}.pdf`;
    doc.save(fileName);

  } catch (error) {
    console.error('PDF export error:', error);
    alert('Failed to export PDF. Please try again.');
  } finally {
    exportingPDF = false;
  }
}

  async function addAttendanceDate() {
    if (!newAttendanceDate || !selectedClassId || !selectedTermIdForAttendance) {
      alert("Please select a date and term");
      return;
    }
    
    const termId = Number(selectedTermIdForAttendance);
    
    // Check if date already exists for this term
    if (attendanceDates[termId]?.includes(newAttendanceDate)) {
      alert("This date is already in the attendance list for this term");
      return;
    }
    
    addingAttendance = true;
    
    // Initialize all students as present for this date (teachers can uncheck as needed)
    const studentIds = filteredStudents
      .filter(s => s.class_id === Number(selectedClassId))
      .map(s => s.student_id);
    
    const attendanceRecordsToInsert = studentIds.map(studentId => ({
      class_id: Number(selectedClassId),
      student_id: studentId,
      attendance_date: newAttendanceDate,
      term_id: termId,
      status: 'Present' // Default to present
    }));
    
    try {
      // Insert records for all students
      if (attendanceRecordsToInsert.length > 0) {
        await supabase
          .from("attendance")
          .insert(attendanceRecordsToInsert);
      }
      
      // Refresh attendance data
      await fetchAttendance(Number(selectedClassId), Number(selectedYearId));
      showAddAttendanceModal = false;
    } catch (error) {
      alert("Failed to add attendance date");
    }
    
    addingAttendance = false;
  }

  // Delete all attendance records for a specific date and term (attendance CRUD - Delete)
  async function deleteAttendanceDate(date: string, termId: number) {
    if (!confirm(`Delete attendance for ${new Date(date).toLocaleDateString()}? This will remove all student records for that date.`)) return;
    if (!selectedClassId) return;
    try {
      await supabase
        .from('attendance')
        .delete()
        .eq('class_id', Number(selectedClassId))
        .eq('attendance_date', date)
        .eq('term_id', termId);

      // Refresh attendance after deletion
      await fetchAttendance(Number(selectedClassId), Number(selectedYearId));
    } catch (err) {
      alert('Failed to delete attendance date');
    }
  }

  function openEditAttendanceModal(date: string, termId: number) {
    editingAttendanceDate = date;
    editingTermId = termId;
    originalAttendanceDate = date;
    showEditAttendanceModal = true;
  }

  async function updateAttendanceDate() {
    if (!selectedClassId || !editingAttendanceDate || !editingTermId) return;
    updatingAttendance = true;
    try {
      await supabase
        .from('attendance')
        .update({ attendance_date: editingAttendanceDate })
        .eq('class_id', Number(selectedClassId))
        .eq('attendance_date', originalAttendanceDate)
        .eq('term_id', editingTermId);

      // Refresh attendance data
      await fetchAttendance(Number(selectedClassId), Number(selectedYearId));
      showEditAttendanceModal = false;
    } catch (err) {
      alert('Failed to update attendance date');
    }
    updatingAttendance = false;
  }
</script>

<section>
  <h2 class="text-2xl font-bold flex items-center gap-2 text-gray-700"><Table2 class="w-5 h-5" /> Grade Book</h2>
  <p class="mt-1 text-gray-500">Record student performances.</p>
</section>
<hr class="my-4 border-gray-200" />

<!-- Filters -->
<div class="flex flex-col gap-3 mb-4 font-sans">
  <div class="flex flex-col sm:flex-row gap-2 w-full">
    <Input type="text" placeholder="Search students..." class="w-full sm:w-60 border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500" bind:value={search} />
    <select class="w-full sm:w-auto border text-gray-500 text-sm border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500" bind:value={selectedYearId}>
      <option value="">Select School Year</option>
      {#each schoolYears as sy}
        <option value={sy.school_year_id}>{sy.school_year}</option>
      {/each}
    </select>
    <select class="w-full sm:w-auto border text-gray-500 text-sm border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500" bind:value={selectedClassId}>
      <option value="">Select Class</option>
      {#each classes as cls}
        <option value={cls.class_id}>{cls.class_name} - {cls.section}</option>
      {/each}
    </select>
  </div>
  <div class="flex flex-wrap gap-2">
    <Button color="green" size="sm" onclick={openAddItemModal} disabled={!selectedClassId} class="flex-shrink-0">
      <Plus class="w-4 h-4 mr-1" /> Add Item
    </Button>
    <Button color="green" size="sm" onclick={openAddAttendanceModal} disabled={!selectedClassId} class="flex-shrink-0">
      <Calendar class="w-4 h-4 mr-1" /> Add Attendance
    </Button>
    <Button color="green" size="sm" onclick={openShareModal} disabled={!selectedClassId} class="flex-shrink-0">
      <Share2 class="w-4 h-4 mr-1" /> Share Class Link
    </Button>
    <Button color="green" size="sm" onclick={exportToPDF} disabled={!selectedClassId || !selectedYearId || exportingPDF} class="flex-shrink-0">
      {#if exportingPDF}
        <Loader class="w-4 h-4 mr-1 animate-spin" />
      {:else}
        <FileDown class="w-4 h-4 mr-1" />
      {/if}
      Export PDF
    </Button>
  </div>
</div>

<Tabs classes={{ active: "p-4 text-green-700 bg-green-100 rounded-t-xs border-l border-green-300 border-t border-green-300 border-r border-green-300" }}>
  <!-- All terms -->
  <TabItem open={activeTabIndex === 0} title="All" onclick={() => saveActiveTabToStorage(0)}>
    {#if selectedClassId && selectedYearId}
      {@const visibleTerms = terms}
      <div class="bg-white rounded-lg shadow border border-gray-200 overflow-hidden">
        <div class="overflow-x-auto overflow-y-visible">
          <table class="w-full">
            <thead>
              <tr class="bg-gray-50 border-b border-gray-200">
                <th class="px-2 sm:px-4 py-2 sm:py-3 text-xs font-semibold text-gray-700 uppercase tracking-wider sticky left-0 bg-gray-50 z-20 border-r border-gray-200">No</th>
                <th class="px-2 sm:px-4 py-2 sm:py-3 text-xs font-semibold text-gray-700 uppercase tracking-wider sticky left-[40px] sm:left-[60px] bg-gray-50 z-20 border-r border-gray-200">ID</th>
                <th class="px-2 sm:px-4 py-2 sm:py-3 text-xs font-semibold text-gray-700 uppercase tracking-wider sticky left-[80px] sm:left-[140px] bg-gray-50 z-20 border-r border-gray-200 shadow-[2px_0_5px_-2px_rgba(0,0,0,0.1)]">Name</th>
                {#each visibleTerms as term}
                  <th class="px-2 sm:px-4 py-2 sm:py-3 text-xs sm:text-sm font-semibold text-gray-700 text-center border-l border-gray-200">{term.term_name}</th>
                {/each}
                <th class="px-2 sm:px-4 py-2 sm:py-3 text-xs font-semibold text-gray-700 uppercase tracking-wider border-l border-gray-300">Final</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              {#if loadingStudents || loadingGrid}
                {#each Array(5) as _, i}
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="px-4 py-3"><div class="h-4 bg-gray-200 rounded animate-pulse w-8"></div></td>
                    <td class="px-4 py-3"><div class="h-4 bg-gray-200 rounded animate-pulse w-20"></div></td>
                    <td class="px-4 py-3"><div class="h-4 bg-gray-200 rounded animate-pulse w-40"></div></td>
                  </tr>
                {/each}
              {:else if paginatedStudents.length === 0}
                <tr>
                  <td colspan={3 + components.reduce((acc, c) => acc + (itemsByComponent[c.component_id]?.length || 0), 0) * visibleTerms.length} class="px-4 py-8 text-center text-gray-500">No students found</td>
                </tr>
              {:else}
                {#each paginatedStudents as student, idx}
                  <tr class="hover:bg-gray-50 transition-colors {idx % 2 === 0 ? 'bg-white' : 'bg-gray-50/30'}">
                    <td class="px-2 sm:px-4 py-2 sm:py-3 text-xs font-medium text-gray-700 sticky left-0 {idx % 2 === 0 ? 'bg-white' : 'bg-gray-50'} z-10 border-r border-gray-200">{startIndex + idx + 1}</td>
                    <td class="px-2 sm:px-4 py-2 sm:py-3 text-xs text-gray-600 sticky left-[40px] sm:left-[60px] {idx % 2 === 0 ? 'bg-white' : 'bg-gray-50'} z-10 border-r border-gray-200">{student.student_code}</td>
                    <td class="px-2 sm:px-4 py-2 sm:py-3 text-xs font-medium text-gray-800 sticky left-[80px] sm:left-[140px] {idx % 2 === 0 ? 'bg-white' : 'bg-gray-50'} z-10 border-r border-gray-200 shadow-[2px_0_5px_-2px_rgba(0,0,0,0.1)]">{student.student_name}</td>
                    {#each visibleTerms as term}
                      {#key `${updateTrigger}-${JSON.stringify(attendancePercentages)}-${JSON.stringify(itemScores)}-${student.student_id}-${term.term_id}`}
                        {@const termAvg = computeTermAverage(student.student_id, term.term_id)}
                        <td class="px-2 sm:px-4 py-2 sm:py-3 text-xs sm:text-sm text-center font-semibold border-l border-gray-200 {getGradeColorClass(termAvg)}">
                          {convertGradeToScale(termAvg)}
                        </td>
                      {/key}
                    {/each}
                    {#key `${updateTrigger}-${JSON.stringify(attendancePercentages)}-${JSON.stringify(itemScores)}-${student.student_id}-final`}
                      {@const finalAvg = computeFinalAverage(student.student_id)}
                      <td class="px-2 sm:px-4 py-2 sm:py-3 text-xs sm:text-sm text-center font-bold border-l border-gray-300 {getGradeColorClass(finalAvg)}">
                        {convertGradeToScale(finalAvg)}
                      </td>
                    {/key}
                  </tr>
                {/each}
              {/if}
            </tbody>
          </table>
        </div>
      </div>
      {#if totalPages > 1}
        <div class="mt-4 bg-white rounded-lg border border-gray-200 p-3">
          <div class="flex flex-col sm:flex-row items-center justify-between gap-3 text-sm">
            <div class="flex items-center gap-2">
              <span class="text-xs sm:text-sm">Items:</span>
              <select class="border border-gray-300 rounded px-2 py-1 text-sm" bind:value={itemsPerPage}>
                <option value={5}>5</option>
                <option value={10}>10</option>
                <option value={20}>20</option>
                <option value={50}>50</option>
              </select>
            </div>
            <div class="text-xs sm:text-sm text-gray-600">Showing {startIndex + 1}-{Math.min(endIndex, filteredStudents.length)} of {filteredStudents.length}</div>
            <div class="flex items-center gap-2">
              <button onclick={() => currentPage = Math.max(1, currentPage - 1)} disabled={currentPage === 1} class="px-2 sm:px-3 py-1 text-xs sm:text-sm border border-gray-300 rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50">Prev</button>
              <div class="hidden sm:flex items-center gap-1">
                {#each Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                  const startPageLocal = Math.max(1, currentPage - 2);
                  const pageNum = startPageLocal + i;
                  if (pageNum > totalPages) return null;
                  return pageNum;
                }) as pageNum}
                  {#if pageNum}
                    <button onclick={() => (currentPage = pageNum)} class="px-3 py-1 border rounded {currentPage === pageNum ? 'bg-gray-900 text-white border-gray-900' : 'border-gray-300 hover:bg-gray-50'}">{pageNum}</button>
                  {/if}
                {/each}
              </div>
              <span class="sm:hidden text-xs text-gray-600">Page {currentPage}/{totalPages}</span>
              <button onclick={() => currentPage = Math.min(totalPages, currentPage + 1)} disabled={currentPage === totalPages} class="px-2 sm:px-3 py-1 text-xs sm:text-sm border border-gray-300 rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50">Next</button>
            </div>
          </div>
        </div>
      {/if}
    {:else}
      <div class="mt-4 p-4 bg-yellow-50 border border-yellow-200 rounded text-sm text-yellow-800">Select a School Year and Class to load the gradesheet.</div>
    {/if}
  </TabItem>

  {#each terms as singleTerm, idx}
    <TabItem title={singleTerm.term_name} open={activeTabIndex === idx + 1} onclick={() => saveActiveTabToStorage(idx + 1)}>
      {#if selectedClassId && selectedYearId}
        {@const visibleTerms = [singleTerm]}
        <div class="bg-white rounded-lg shadow border border-gray-200 overflow-hidden">
          <div class="overflow-x-auto -mx-4 sm:mx-0">
            <table class="w-full">
              <thead>
                <tr class="bg-gray-50 border-b border-gray-200">
                  <th class="px-2 sm:px-4 py-2 sm:py-3 text-xs font-semibold text-gray-700 uppercase tracking-wider sticky left-0 bg-gray-50 z-20 border-r border-gray-200" rowspan="4">No</th>
                  <th class="px-2 sm:px-4 py-2 sm:py-3 text-xs font-semibold text-gray-700 uppercase tracking-wider sticky left-[40px] sm:left-[60px] bg-gray-50 z-20 border-r border-gray-200" rowspan="4">ID</th>
                  <th class="px-2 sm:px-4 py-2 sm:py-3 text-xs font-semibold text-gray-700 uppercase tracking-wider sticky left-[80px] sm:left-[140px] bg-gray-50 z-20 border-r border-gray-200 shadow-[2px_0_5px_-2px_rgba(0,0,0,0.1)]" rowspan="4">Name</th>
                  {#each visibleTerms as term}
                    {@const termItemCount = components.reduce((acc, c) => {
                      const items = (itemsByComponent[c.component_id] || []).filter(it => !it.term_id || it.term_id === term.term_id);
                      return acc + (items.length > 0 ? items.length + 1 : 0);
                    }, 0)}
                    <th class="px-2 sm:px-4 py-2 sm:py-3 text-xs sm:text-sm font-semibold text-gray-700 text-center border-l border-gray-300" colspan={termItemCount + 3 + (attendanceDates[term.term_id]?.length || 0)}>{term.term_name}</th>
                  {/each}
                </tr>
                <tr class="bg-gray-50 border-b border-gray-200">
                  {#each visibleTerms as term}
                    {#each components as comp}
                      {@const items = (itemsByComponent[comp.component_id] || []).filter(it => !it.term_id || it.term_id === term.term_id)}
                      {#if items.length > 0}
                        {@const weight = componentWeights[comp.component_id] || 0}
                        {@const weightPercent = (weight * 100).toFixed(1)}
                        <th class="px-2 sm:px-3 py-2 text-[10px] sm:text-xs font-semibold text-gray-700 text-center border-l border-gray-200" colspan={items.length + 1}>{comp.component_name} ({weightPercent}%)</th>
                      {/if}
                    {/each}
                    <th class="px-2 sm:px-3 py-2 text-[10px] sm:text-xs font-semibold text-gray-700 text-center border-l border-gray-300" rowspan="3">Behavior (2.5%)</th>
                    <th class="px-2 sm:px-3 py-2 text-[10px] sm:text-xs font-semibold text-gray-700 text-center border-l border-gray-300" colspan={(attendanceDates[term.term_id]?.length || 0) + 1}>Attendance (2.5%)</th>
                    <th class="px-2 sm:px-3 py-2 text-[10px] sm:text-xs font-semibold text-gray-700 text-center border-l border-gray-300" rowspan="3">Term</th>
                  {/each}
                </tr>
                <tr class="bg-white border-b border-gray-200">
                  {#each visibleTerms as term}
                    {#each components as comp}
                      {@const items = (itemsByComponent[comp.component_id] || []).filter(it => !it.term_id || it.term_id === term.term_id)}
                      {#each items as it}
                        <th class="px-2 sm:px-3 py-2 text-[10px] sm:text-[11px] font-medium text-gray-600 border-l border-gray-100">
                          <div class="flex items-center justify-center gap-1">
                            <span>{it.title}</span>
                            <div class="flex gap-0.5">
                              <button onclick={() => openEditItemModal(it)} class="p-0.5 hover:bg-gray-100 rounded transition-colors" title="Edit">
                                <Pencil class="w-3 h-3 text-green-600" />
                              </button>
                              <button onclick={() => deleteItem(it.item_id)} class="p-0.5 hover:bg-gray-100 rounded transition-colors" title="Delete">
                                <Trash2 class="w-3 h-3 text-red-600" />
                              </button>
                            </div>
                          </div>
                        </th>
                      {/each}
                      {#if items.length > 0}
                        <th class="px-2 py-2 text-[10px] font-semibold text-gray-700 text-center border-l border-gray-200" rowspan="2">%</th>
                      {/if}
                    {/each}
                    {#each (attendanceDates[term.term_id] || []) as date}
                      <th class="px-2 py-2 text-[10px] font-medium text-gray-600 border-l border-gray-100">
                        <div class="flex items-center justify-center gap-1">
                          <span>{new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}</span>
                          <div class="flex gap-0.5">
                            <button onclick={() => openEditAttendanceModal(date, term.term_id)} class="p-0.5 hover:bg-gray-100 rounded transition-colors" title="Edit">
                              <Pencil class="w-3 h-3 text-green-600" />
                            </button>
                            <button title="Delete attendance date" class="p-0.5 hover:bg-red-50 rounded transition-colors" onclick={() => deleteAttendanceDate(date, term.term_id)}>
                              <Trash2 class="w-3 h-3 text-red-600" />
                            </button>
                          </div>
                        </div>
                      </th>
                    {/each}
                    <th class="px-2 py-2 text-[10px] font-semibold text-gray-700 text-center border-l border-gray-200" rowspan="2">%</th>
                  {/each}
                </tr>
                <tr class="bg-gray-50 border-b border-gray-300">
                  {#each visibleTerms as term}
                    {#each components as comp}
                      {@const items = (itemsByComponent[comp.component_id] || []).filter(it => !it.term_id || it.term_id === term.term_id)}
                      {#each items as it}
                        <th class="px-2 py-2 border-l border-gray-100">
                          <div class="flex flex-col items-center gap-0.5">
                            <span class="text-[10px] text-gray-500">{formatDate(it.created_at)}</span>
                            <span class="text-[10px] font-semibold text-gray-600">Max: {it.number_of_items}</span>
                          </div>
                        </th>
                      {/each}
                    {/each}
                    {#each (attendanceDates[term.term_id] || []) as date}
                      <th class="px-2 py-2 text-[9px] text-gray-500 border-l border-gray-100">
                        {new Date(date).toLocaleDateString('en-US', { weekday: 'short' })}
                      </th>
                    {/each}
                  {/each}
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                {#if loadingStudents || loadingGrid}
                  {#each Array(5) as _, i}
                    <tr class="hover:bg-gray-50 transition-colors">
                      <td class="px-4 py-3"><div class="h-4 bg-gray-200 rounded animate-pulse w-8"></div></td>
                      <td class="px-4 py-3"><div class="h-4 bg-gray-200 rounded animate-pulse w-20"></div></td>
                      <td class="px-4 py-3"><div class="h-4 bg-gray-200 rounded animate-pulse w-40"></div></td>
                    </tr>
                  {/each}
                {:else if paginatedStudents.length === 0}
                  <tr>
                    <td colspan={3 + components.reduce((acc, c) => acc + (itemsByComponent[c.component_id]?.length || 0), 0)} class="px-4 py-8 text-center text-gray-500">No students found</td>
                  </tr>
                {:else}
                  {#each paginatedStudents as student, idx}
                    <tr class="hover:bg-gray-50 transition-colors {idx % 2 === 0 ? 'bg-white' : 'bg-gray-50/30'}">
                      <td class="px-2 sm:px-4 py-2 sm:py-3 text-xs font-medium text-gray-700 sticky left-0 {idx % 2 === 0 ? 'bg-white' : 'bg-gray-50'} z-10 border-r border-gray-200">{startIndex + idx + 1}</td>
                      <td class="px-2 sm:px-4 py-2 sm:py-3 text-xs text-gray-600 sticky left-[40px] sm:left-[60px] {idx % 2 === 0 ? 'bg-white' : 'bg-gray-50'} z-10 border-r border-gray-200">{student.student_code}</td>
                      <td class="px-2 sm:px-4 py-2 sm:py-3 text-xs font-medium text-gray-800 sticky left-[80px] sm:left-[140px] {idx % 2 === 0 ? 'bg-white' : 'bg-gray-50'} z-10 border-r border-gray-200 shadow-[2px_0_5px_-2px_rgba(0,0,0,0.1)]">{student.student_name}</td>
                      {#each visibleTerms as term}
                        {#each components as comp}
                          {@const items = (itemsByComponent[comp.component_id] || []).filter(it => !it.term_id || it.term_id === term.term_id)}
                          {#each items as it}
                            {#key `${student.student_id}-${it.item_id}`}
                              {@const scoreValue = itemScores[keyItem(student.student_id, term.term_id, comp.component_id, it.item_id)]}
                              <td class="px-2 py-2 text-center border-l border-gray-100">
                                <input 
                                  type="number" 
                                  min="0" 
                                  max={it.number_of_items}
                                  class="w-12 sm:w-16 px-1 sm:px-2 py-1 sm:py-1.5 text-xs text-center border border-gray-300 rounded focus:ring-1 focus:ring-green-400 focus:border-green-400 hover:border-green-400 transition-colors" 
                                  value={scoreValue !== undefined && scoreValue !== null ? scoreValue : ''} 
                                  oninput={(e) => onItemChange(student.student_id, term.term_id, comp.component_id, it.item_id, e)} 
                                  placeholder="-"
                                />
                              </td>
                            {/key}
                          {/each}
                          {#if items.length > 0}
                            {#key updateTrigger}
                              <td class="px-2 py-2 text-xs text-center font-semibold text-gray-700 border-l border-gray-200 bg-gray-50">
                                {computeComponentPercentage(student.student_id, term.term_id, comp.component_id).toFixed(2)}%
                              </td>
                            {/key}
                          {/if}
                        {/each}
                        {#key updateTrigger}
                          <td class="px-2 py-2 text-xs text-center font-semibold text-gray-700 border-l border-gray-300 bg-gray-50">
                            {computeBehaviorPercentage(student.student_id, term.term_id).toFixed(2)}%
                          </td>
                        {/key}
                        {#each (attendanceDates[term.term_id] || []) as date}
                          {#key `${student.student_id}-${term.term_id}-${date}`}
                            {@const studentTermKey = `${student.student_id}-${term.term_id}`}
                            {@const isPresent = attendanceRecords[studentTermKey]?.has(date) ?? false}
                            <td class="px-2 py-2 text-center border-l border-gray-100">
                              <input 
                                type="checkbox" 
                                checked={isPresent}
                                onchange={(e) => toggleAttendance(student.student_id, term.term_id, date, (e.target as HTMLInputElement).checked)}
                                class="w-4 h-4 text-gray-600 border-gray-300 rounded focus:ring-1 focus:ring-gray-400 cursor-pointer"
                                title={`Mark attendance for ${date}`}
                              />
                            </td>
                          {/key}
                        {/each}
                        <td class="px-2 py-2 text-xs text-center font-semibold text-gray-700 border-l border-gray-200 bg-gray-50">
                          {#key `${student.student_id}-${term.term_id}-percentage`}
                            {@const attendanceKey = keyAttendance(student.student_id, term.term_id, Number(selectedYearId))}
                            {@const attendancePercentage = attendancePercentages[attendanceKey] || 60}
                            {@const finalAttendanceScore = (attendancePercentage * 0.025).toFixed(2)}
                            {finalAttendanceScore}%
                          {/key}
                        </td>
                        {#key `${updateTrigger}-${JSON.stringify(attendancePercentages)}-${JSON.stringify(itemScores)}-${student.student_id}-${term.term_id}`}
                          {@const termAvg = computeTermAverage(student.student_id, term.term_id)}
                          <td class="px-2 py-2 text-xs text-center font-bold border-l border-gray-300 {getGradeColorClass(termAvg)}">
                            {termAvg.toFixed(2)}
                          </td>
                        {/key}
                      {/each}
                    </tr>
                  {/each}
                {/if}
              </tbody>
            </table>
          </div>
        </div>
        {#if totalPages > 1}
          <div class="mt-4 bg-white rounded-lg border border-gray-200 p-3">
            <div class="flex flex-col sm:flex-row items-center justify-between gap-3 text-sm">
              <div class="flex items-center gap-2">
                <span class="text-xs sm:text-sm">Items:</span>
                <select class="border border-gray-300 rounded px-2 py-1 text-sm" bind:value={itemsPerPage}>
                  <option value={5}>5</option>
                  <option value={10}>10</option>
                  <option value={20}>20</option>
                  <option value={50}>50</option>
                </select>
              </div>
              <div class="text-xs sm:text-sm text-gray-600">Showing {startIndex + 1}-{Math.min(endIndex, filteredStudents.length)} of {filteredStudents.length}</div>
              <div class="flex items-center gap-2">
                <button onclick={() => currentPage = Math.max(1, currentPage - 1)} disabled={currentPage === 1} class="px-2 sm:px-3 py-1 text-xs sm:text-sm border border-gray-300 rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50">Prev</button>
                <div class="hidden sm:flex items-center gap-1">
                  {#each Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                    const startPageLocal = Math.max(1, currentPage - 2);
                    const pageNum = startPageLocal + i;
                    if (pageNum > totalPages) return null;
                    return pageNum;
                  }) as pageNum}
                    {#if pageNum}
                      <button onclick={() => (currentPage = pageNum)} class="px-3 py-1 border rounded {currentPage === pageNum ? 'bg-gray-900 text-white border-gray-900' : 'border-gray-300 hover:bg-gray-50'}">{pageNum}</button>
                    {/if}
                  {/each}
                </div>
                <span class="sm:hidden text-xs text-gray-600">Page {currentPage}/{totalPages}</span>
                <button onclick={() => currentPage = Math.min(totalPages, currentPage + 1)} disabled={currentPage === totalPages} class="px-2 sm:px-3 py-1 text-xs sm:text-sm border border-gray-300 rounded disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50">Next</button>
              </div>
            </div>
          </div>
        {/if}
      {:else}
        <div class="mt-4 p-4 bg-yellow-50 border border-yellow-200 rounded text-sm text-yellow-800">Select a School Year and Class to load the gradesheet.</div>
      {/if}
    </TabItem>
  {/each}
</Tabs>

{#if showAddItemModal}
  <div class="fixed inset-0 bg-black/40 flex items-center justify-center z-50 px-4 font-sans">
    <div class="bg-white rounded-lg shadow-lg w-full max-w-md p-6 relative">
      <button
        onclick={() => showAddItemModal = false}
        class="absolute top-3 right-3 text-gray-500 hover:text-gray-700"
      >
        <X class="w-5 h-5" />
      </button>

      <Label class="text-lg font-semibold mb-4 text-center sm:text-left">
        Add New Grade Item
      </Label>

      <div class="space-y-3">
        <select
          class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500 font-sans text-gray-500"
          bind:value={selectedTermId}
        >
          <option value="">Select Term</option>
          {#each terms as term}
            <option value={term.term_id}>{term.term_name}</option>
          {/each}
        </select>

        <select
          class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500 font-sans text-gray-500"
          bind:value={selectedComponentId}
        >
          <option value="">Select Component</option>
          {#each components as comp}
            <option value={comp.component_id}>{comp.component_name}</option>
          {/each}
        </select>

        <Input
          type="text"
          placeholder="Item Title (e.g., Quiz 1, Assignment 1)"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
          bind:value={newItemTitle}
        />

        <Input
          type="number"
          min="1"
          placeholder="Maximum Score"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
          bind:value={newItemMaxScore}
        />
      </div>

      <div class="mt-5 flex flex-col sm:flex-row justify-end gap-2">
        <Button
          onclick={() => showAddItemModal = false}
          class="w-full sm:w-auto px-4 py-2 border border-gray-300 rounded-lg text-gray-600 hover:bg-gray-100"
          disabled={addingItem}
        >
          Cancel
        </Button>
        <Button
          onclick={addNewItem}
          class="w-full sm:w-auto px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          disabled={addingItem || !newItemTitle.trim() || !selectedComponentId || !selectedTermId}
        >
          {#if addingItem}
            <Loader class="w-4 h-4 animate-spin" />
          {/if}
          Add Item
        </Button>
      </div>
    </div>
  </div>
{/if}

{#if showEditItemModal}
  <div class="fixed inset-0 bg-black/40 flex items-center justify-center z-50 px-4 font-sans">
    <div class="bg-white rounded-lg shadow-lg w-full max-w-md p-4 sm:p-6 relative">
      <button
        onclick={() => { showEditItemModal = false; editingItem = null; }}
        class="absolute top-3 right-3 text-gray-500 hover:text-gray-700"
      >
        <X class="w-5 h-5" />
      </button>

      <Label class="text-lg font-semibold mb-4 text-center sm:text-left">
        Edit Grade Item
      </Label>

      <div class="space-y-3">
        <Input
          type="text"
          placeholder="Item Title (e.g., Quiz 1, Assignment 1)"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
          bind:value={editItemTitle}
        />

        <Input
          type="number"
          min="1"
          placeholder="Maximum Score"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
          bind:value={editItemMaxScore}
        />

        <Input
          type="date"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
          bind:value={editItemDate}
        />
      </div>

      <div class="mt-5 flex flex-col sm:flex-row justify-end gap-2">
        <Button
          onclick={() => { showEditItemModal = false; editingItem = null; }}
          class="w-full sm:w-auto px-4 py-2 border border-gray-300 rounded-lg text-gray-600 hover:bg-gray-100"
          disabled={updatingItem}
        >
          Cancel
        </Button>
        <Button
          onclick={updateItem}
          class="w-full sm:w-auto px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          disabled={updatingItem || !editItemTitle.trim()}
        >
          {#if updatingItem}
            <Loader class="w-4 h-4 animate-spin" />
          {/if}
          Update Item
        </Button>
      </div>
    </div>
  </div>
{/if}

{#if showEditAttendanceModal}
  <div class="fixed inset-0 bg-black/40 flex items-center justify-center z-50 px-4 font-sans">
    <div class="bg-white rounded-lg shadow-lg w-full max-w-md p-6 relative">
      <button
        onclick={() => { showEditAttendanceModal = false; }}
        class="absolute top-3 right-3 text-gray-500 hover:text-gray-700"
      >
        <X class="w-5 h-5" />
      </button>

      <Label class="text-lg font-semibold mb-4 text-center sm:text-left">
        Edit Attendance Date
      </Label>

      <div class="space-y-4">
        <div>
          <Label class="text-sm text-gray-600 mb-2">Select Term</Label>
          <select
            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500 font-sans text-gray-500"
            bind:value={editingTermId}
          >
            <option value="">Select Term</option>
            {#each terms as term}
              <option value={term.term_id}>{term.term_name}</option>
            {/each}
          </select>
        </div>
        <div>
          <Label class="text-sm text-gray-600 mb-2">Select Date</Label>
          <Input
            type="date"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
            bind:value={editingAttendanceDate}
          />
          <p class="text-xs text-gray-500 mt-2">This will update the date for all students' attendance records.</p>
        </div>
      </div>

      <div class="mt-5 flex flex-col sm:flex-row justify-end gap-2">
        <Button
          onclick={() => { showEditAttendanceModal = false; }}
          class="w-full sm:w-auto px-4 py-2 border border-gray-300 rounded-lg text-gray-600 hover:bg-gray-100"
          disabled={updatingAttendance}
        >
          Cancel
        </Button>
        <Button
          onclick={updateAttendanceDate}
          class="w-full sm:w-auto px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          disabled={updatingAttendance || !editingAttendanceDate || !editingTermId}
        >
          {#if updatingAttendance}
            <Loader class="w-4 h-4 animate-spin" />
          {/if}
          Update Date
        </Button>
      </div>
    </div>
  </div>
{/if}

{#if showAddAttendanceModal}
  <div class="fixed inset-0 bg-black/40 flex items-center justify-center z-50 px-4 font-sans">
    <div class="bg-white rounded-lg shadow-lg w-full max-w-md p-4 sm:p-6 relative">
      <button
        onclick={() => showAddAttendanceModal = false}
        class="absolute top-3 right-3 text-gray-500 hover:text-gray-700"
      >
        <X class="w-5 h-5" />
      </button>

      <Label class="text-lg font-semibold mb-4 text-center sm:text-left">
        Add Attendance Date
      </Label>

      <div class="space-y-4">
        <div>
          <Label class="text-sm text-gray-600 mb-2">Select Term</Label>
          <select
            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-400 font-sans text-gray-500"
            bind:value={selectedTermIdForAttendance}
          >
            <option value="">Select Term</option>
            {#each terms as term}
              <option value={term.term_id}>{term.term_name}</option>
            {/each}
          </select>
        </div>
        <div>
          <Label class="text-sm text-gray-600 mb-2">Select Date</Label>
          <Input
            type="date"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
            bind:value={newAttendanceDate}
          />
          <p class="text-xs text-gray-500 mt-2">All students will be marked as present by default. You can uncheck individual students as needed.</p>
        </div>
      </div>

      <div class="mt-5 flex flex-col sm:flex-row justify-end gap-2">
        <Button
          onclick={() => showAddAttendanceModal = false}
          class="w-full sm:w-auto px-4 py-2 border border-gray-300 rounded-lg text-gray-600 hover:bg-gray-100"
          disabled={addingAttendance}
        >
          Cancel
        </Button>
        <Button
          onclick={addAttendanceDate}
          class="w-full sm:w-auto px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          disabled={addingAttendance || !newAttendanceDate || !selectedTermIdForAttendance}
        >
          {#if addingAttendance}
            <Loader class="w-4 h-4 animate-spin" />
          {/if}
          Add Date
        </Button>
      </div>
    </div>
  </div>
{/if}

{#if showShareModal}
  <div class="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4 font-sans overflow-y-auto">
    <div class="bg-white rounded-lg shadow-lg w-full max-w-4xl p-4 sm:p-6 relative my-auto">
      <button
        onclick={() => showShareModal = false}
        class="absolute top-3 right-3 text-gray-500 hover:text-gray-700 p-2 touch-manipulation"
      >
        <X class="w-5 h-5" />
      </button>

      <div class="flex items-center gap-2 mb-4">
        <Share2 class="w-6 h-6 text-green-600 flex-shrink-0" />
        <Label class="text-lg font-semibold text-left">
          Share Class Grade Link
        </Label>
      </div>

      <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-3 flex items-start gap-2 mb-4">
        <AlertCircle class="w-4 h-4 text-yellow-600 mt-0.5 flex-shrink-0" />
        <p class="text-xs sm:text-sm text-yellow-800">
          <strong>Security Notice:</strong> This link will expire in 1 hour. Generate a new link or QR code if needed.
        </p>
      </div>

      <!-- Responsive Layout -->
      <div class="grid sm:grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Left Column: QR Code -->
        <div class="space-y-4">
          <h3 class="text-sm font-semibold text-gray-700">QR Code</h3>
          <p class="text-xs sm:text-sm text-gray-600">Students can scan this QR code to access their grades</p>
          
          {#if qrCodeDataUrl}
            <div class="flex justify-center">
              <div class="bg-white p-3 sm:p-4 rounded-lg border-2 border-gray-200 shadow-sm">
                <img src={qrCodeDataUrl} alt="QR Code" class="w-48 h-48 sm:w-64 sm:h-64" />
              </div>
            </div>
            
            <button
              onclick={downloadQRCode}
              class="w-full flex items-center justify-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
            >
              <QrCode class="w-4 h-4" />
              Download QR Code
            </button>
          {:else}
            <div class="flex justify-center py-8">
              <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-green-600"></div>
            </div>
          {/if}
        </div>

        <!-- Right Column: Link -->
        <div class="space-y-4">
          <h3 class="text-sm font-semibold text-gray-700">Share Link</h3>
          <p class="text-xs text-gray-600">Copy and share this link with your students</p>
          
          <div class="bg-gray-50 border border-gray-300 rounded-lg p-3 break-all text-xs sm:text-sm text-gray-700 font-mono overflow-x-auto">
            {shareLink}
          </div>

          <button
            onclick={copyClassShareLink}
            class="w-full flex items-center justify-center gap-2 px-4 py-3 sm:py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 active:bg-green-800 transition-colors disabled:bg-gray-400 touch-manipulation"
            disabled={copiedLink}
          >
            {#if copiedLink}
              <Check class="w-4 h-4" />
              Link Copied!
            {:else}
              <Copy class="w-4 h-4" />
              Copy Link
            {/if}
          </button>
        </div>
      </div>

      <div class="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
        <p class="text-xs text-blue-800">
          <strong>📱 Instructions:</strong> Students can scan the QR code or click the link, then enter their Student ID to view their personalized grades.
        </p>
      </div>
    </div>
  </div>
{/if}