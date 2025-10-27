<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import { Input, Table, TableBody, TableBodyCell, TableBodyRow, TableHead, TableHeadCell, Button, Toast, Label } from "flowbite-svelte";
  import { ClipboardList, FileSpreadsheet, User, Users, Loader, BadgeCheckIcon, Frown, Plus, UserPlus, Siren } from "lucide-svelte";
  import { read, utils } from "xlsx";
  import { supabase } from "../lib/supabase";
  import type { RealtimeChannel } from "@supabase/supabase-js";
  import { fly } from "svelte/transition";
  import X from "@lucide/svelte/icons/x";

  interface SchoolYear {
    school_year_id: number;
    school_year: string;
  }

  type SortKey = 'student_code' | 'student_name' | 'class_name' | 'section' | 'school_year';
  type SortDir = 'asc' | 'desc';
  let sortKey: SortKey = 'student_name';
  let sortDir: SortDir = 'asc';

  function toggleSort(key: SortKey) {
    if (sortKey === key) {
      sortDir = sortDir === 'asc' ? 'desc' : 'asc';
    } else {
      sortKey = key;
      sortDir = 'asc';
    }
  }

  function getSortIcon(key: SortKey) {
    if (sortKey !== key) return '↕';
    return sortDir === 'asc' ? '↑' : '↓';
  }

  interface Class {
    class_id: number;
    class_name: string;
    class_code: string;
    section: string;
    school_year_id?: number;
    instructor_id?: number;
    school_year?: number;
    instructor?: number;
    schoolyear: SchoolYear | null;
    instructor_info?: any | null;
  }

  interface Student {
    student_id: number;
    student_name: string;
    student_code: string;
    created_at: string;
    class_id: number;
    class?: Class | null;
  }

  interface StudentRow {
    No: number;
    Code: string;
    Name: string;
  }

  let students: Student[] = [];
  let schoolYears: SchoolYear[] = [];
  let classes: Class[] = [];
  let file: File | null = null;
  let data: StudentRow[] = [];
  let search = "";
  let selectedYearId: number | "" = "";
  let selectedClassId: number | "" = "";
  let showToast = false;
  let toastMessage = "";
  let toastType = "success";
  let loading = false;
  let channel: RealtimeChannel | null = null;
  let importClassId: number | "" = "";
  let importing = false;
  let showImportModal = false;
  let currentPage = 1;
  let itemsPerPage = 10;
  let mainTableCurrentPage = 1;
  let mainTableItemsPerPage = 10;
  // Upload/loading state for file parsing
  let uploadingFile = false;

  // Add/Edit/Delete state (modal layout consistent with Classes.svelte)
  let showStudentModal = false;
  let editingStudent: Student | null = null;
  let deleteModal = false;
  let studentToDelete: Student | null = null;
  let savingStudent = false;

  let newStudent = {
    student_code: "",
    student_name: "",
    class_id: "" as number | "",
  };

  function resetNewStudent() {
    newStudent = { student_code: "", student_name: "", class_id: "" };
  }

  function openAddStudentModal() {
    editingStudent = null;
    resetNewStudent();
    // prefill class with current filter if any
    if (selectedClassId) newStudent.class_id = selectedClassId;
    showStudentModal = true;
  }

  function openEditStudentModal(student: Student) {
    editingStudent = student;
    newStudent = {
      student_code: student.student_code,
      student_name: student.student_name,
      class_id: student.class_id || student.class?.class_id || "",
    };
    showStudentModal = true;
  }

  function openDeleteStudentModal(student: Student) {
    studentToDelete = student;
    deleteModal = true;
  }

  async function saveStudent() {
    const classIdNum = Number(newStudent.class_id);
    if (!newStudent.student_code || !newStudent.student_name || !classIdNum) {
      showToastNotification("All fields are required", "error");
      return;
    }
    try {
      savingStudent = true;
      if (editingStudent) {
        const { error } = await supabase
          .from("student")
          .update({
            student_code: newStudent.student_code,
            student_name: newStudent.student_name,
            class: classIdNum,
          })
          .eq("student_id", editingStudent.student_id);
        if (error) throw error;
        showToastNotification("Student updated successfully!");
      } else {
        const { error } = await supabase.from("student").insert([
          {
            student_code: newStudent.student_code,
            student_name: newStudent.student_name,
            class: classIdNum,
          },
        ]);
        if (error) throw error;
        showToastNotification("Student added successfully!");
      }
      showStudentModal = false;
      resetNewStudent();
      await fetchStudents();
    } catch (e: any) {
      console.error(e);
      showToastNotification("Error saving student: " + (e.message || e), "error");
    } finally {
      savingStudent = false;
    }
  }

  async function confirmDeleteStudent() {
    if (!studentToDelete) return;
    try {
      // Delete related records first to avoid foreign key constraint errors
      const studentId = studentToDelete.student_id;
      
      // Delete attendance records
      await supabase
        .from("attendance")
        .delete()
        .eq("student_id", studentId);
      
      // Delete grade records
      await supabase
        .from("grade")
        .delete()
        .eq("student_grade", studentId);
      
      // Delete item scores (already has CASCADE in schema, but delete explicitly to be safe)
      await supabase
        .from("item_scores")
        .delete()
        .eq("student_id", studentId);
      
      // Finally delete the student
      const { error } = await supabase
        .from("student")
        .delete()
        .eq("student_id", studentId);
        
      if (error) throw error;
      showToastNotification("Student deleted successfully!");
      await fetchStudents();
    } catch (e: any) {
      showToastNotification("Error deleting student: " + (e.message || e), "error");
    } finally {
      deleteModal = false;
      studentToDelete = null;
    }
  }

  function showToastNotification(message: string, type: "success" | "error" = "success") {
    toastMessage = message;
    toastType = type;
    showToast = true;
    setTimeout(() => {
      showToast = false;
    }, 3000);
  }

  async function handleFileChange(event: Event) {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      try {
        uploadingFile = true;
        file = input.files[0];
        const rows = await parseExcel(file);
        data = rows;
        currentPage = 1; // Reset to first page
        showImportModal = true; // Open modal
      } catch (e) {
        console.error(e);
        showToastNotification('Failed to read file', 'error');
      } finally {
        uploadingFile = false;
      }
    }
  }

  function toTitleCase(str: string) {
    return str
      .toLowerCase()
      .split(" ")
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(" ");
  }

  async function parseExcel(file: File): Promise<StudentRow[]> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();

      reader.onload = (e) => {
        const arrayBuffer = e.target?.result;
        if (!arrayBuffer) return reject("Failed to read file");

        const workbook = read(arrayBuffer, { type: "array" });
        const sheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[sheetName];

        const json = utils.sheet_to_json(worksheet, { defval: "" });

        const rows: StudentRow[] = json
          .map((row: any, index) => ({
            No: index + 1,
            Code: row["Code"] || "",
            Name: toTitleCase(row["Name"] || "")
          }))
          .filter(row => row.Code && row.Name);

        resolve(rows);
      };

      reader.onerror = () => reject("File reading error");
      reader.readAsArrayBuffer(file);
    });
  }

  async function fetchSchoolYears() {
    const { data, error } = await supabase
      .from("schoolyear")
      .select("school_year_id, school_year")
      .order("school_year", { ascending: true });
    if (!error) schoolYears = data || [];
  }

  async function fetchClasses() {
    const { data, error } = await supabase
      .from("class")
      .select(
        `
          class_id,
          class_name,
          class_code,
          section,
          instructor,
          school_year,
          instructor:instructor (instructor_id, instructor_name),
          schoolyear:school_year (school_year_id, school_year)
        `
      )
      .filter("is_archived","eq", false)
      .order("class_name", { ascending: true });

    if (error) {
      console.error("Fetch classes error:", error);
      return;
    } else {
      classes = (data || []).map((cls: any) => ({
        ...cls,
        instructor_info: cls.instructor,
        schoolyear: cls.schoolyear?.[0] || null
      }));
    }
  }

async function fetchStudents() {
  loading = true;
  const { data, error } = await supabase
    .from("student")
    .select(`
      student_id,
      student_name,
      student_code,
      created_at,
      class (
        class_id,
        class_name,
        class_code,
        section,
        is_archived,
        schoolyear:school_year (
          school_year_id,
          school_year
        )
      )
    `)
    .eq("class.is_archived", false)
    .order("student_name", { ascending: true });

  if (error) {
    console.error("Fetch students error:", error);
    showToastNotification("Error fetching students: " + error.message, "error");
  } else {
    students = (data || []).map((student: any) => ({
      student_id: student.student_id,
      student_code: student.student_code,
      student_name: student.student_name,
      created_at: student.created_at,
      class_id: student.class?.class_id || 0,
      class: student.class || null
    }));
  }
  loading = false;
}


  onMount(async () => {
    await fetchSchoolYears();
    await fetchClasses();
    await fetchStudents();

    channel = supabase
      .channel("student-changes")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "student" },
        async () => {
          await fetchStudents();
        }
      )
      .subscribe();
  });

  onDestroy(() => {
    if (channel) supabase.removeChannel(channel);
  });

  $: filteredStudents = students
    .filter(
      (student) =>
        (!search || student.student_name.toLowerCase().includes(search.toLowerCase())) &&
        (!selectedYearId || student.class?.schoolyear?.school_year_id === Number(selectedYearId)) &&
        (!selectedClassId || student.class?.class_id === Number(selectedClassId))
    )
    .slice()
    .sort((a, b) => {
      const dir = sortDir === 'asc' ? 1 : -1;
      switch (sortKey) {
        case 'student_code':
          return (a.student_code || '').localeCompare(b.student_code || '') * dir;
        case 'student_name':
          return (a.student_name || '').localeCompare(b.student_name || '') * dir;
        case 'class_name':
          return (a.class?.class_name || '').localeCompare(b.class?.class_name || '') * dir;
        case 'section':
          return (a.class?.section || '').localeCompare(b.class?.section || '') * dir;
        case 'school_year':
          return (a.class?.schoolyear?.school_year || '').localeCompare(b.class?.schoolyear?.school_year || '') * dir;
        default:
          return 0;
      }
    });

  // Reset main table pagination when filters change
  $: if (search || selectedYearId || selectedClassId) {
    mainTableCurrentPage = 1;
  }

  $: filteredData = data.filter(
    row =>
      row.Code.toLowerCase().includes(search.toLowerCase()) ||
      row.Name.toLowerCase().includes(search.toLowerCase())
  );

  async function importStudents() {
    if (!importClassId) {
      showToastNotification("Please select a class for the imported students", "error");
      return;
    }

    if (data.length === 0) {
      showToastNotification("No data to import. Please select an Excel file first.", "error");
      return;
    }

    importing = true;
    let successCount = 0;
    let errorCount = 0;
    const errors: string[] = [];

    try {
      // Process students in batches to avoid overwhelming the database
      const batchSize = 10;
      for (let i = 0; i < data.length; i += batchSize) {
        const batch = data.slice(i, i + batchSize);
        
        const studentsToInsert = batch.map(row => ({
          student_code: row.Code,
          student_name: row.Name,
          class: Number(importClassId)
        }));

        const { data: insertedStudents, error } = await supabase
          .from("student")
          .insert(studentsToInsert)
          .select();

        if (error) {
          console.error("Batch insert error:", error);
          errorCount += batch.length;
          errors.push(`Batch ${Math.floor(i / batchSize) + 1}: ${error.message}`);
        } else {
          successCount += insertedStudents?.length || 0;
        }
      }

      if (successCount > 0) {
        showToastNotification(
          `Successfully imported ${successCount} students. ${errorCount > 0 ? `${errorCount} failed.` : ""}`,
          errorCount > 0 ? "error" : "success"
        );
        
        // Clear the imported data and reset form
        data = [];
        file = null;
        importClassId = "";
        currentPage = 1;
        showImportModal = false;
        
        // Refresh the students list
        await fetchStudents();
      } else {
        showToastNotification("Failed to import any students. Please check the data and try again.", "error");
      }

      if (errors.length > 0) {
        console.error("Import errors:", errors);
      }

    } catch (error) {
      console.error("Import error:", error);
      showToastNotification("An unexpected error occurred during import", "error");
    } finally {
      importing = false;
    }
  }

  function clearImportData() {
    data = [];
    file = null;
    importClassId = "";
    currentPage = 1;
    showImportModal = false;
    // Reset the file input
    const fileInput = document.querySelector('input[type="file"]') as HTMLInputElement;
    if (fileInput) {
      fileInput.value = "";
    }
  }

  function closeImportModal() {
    showImportModal = false;
  }

  // Pagination logic for import modal
  $: totalPages = Math.ceil(filteredData.length / itemsPerPage);
  $: startIndex = (currentPage - 1) * itemsPerPage;
  $: endIndex = startIndex + itemsPerPage;
  $: paginatedData = filteredData.slice(startIndex, endIndex);

  // Pagination logic for main table
  $: mainTableTotalPages = Math.ceil(filteredStudents.length / mainTableItemsPerPage);
  $: mainTableStartIndex = (mainTableCurrentPage - 1) * mainTableItemsPerPage;
  $: mainTableEndIndex = mainTableStartIndex + mainTableItemsPerPage;
  $: paginatedStudents = filteredStudents.slice(mainTableStartIndex, mainTableEndIndex);

  function goToPage(page: number) {
    if (page >= 1 && page <= totalPages) {
      currentPage = page;
    }
  }

  function nextPage() {
    if (currentPage < totalPages) {
      currentPage++;
    }
  }

  function prevPage() {
    if (currentPage > 1) {
      currentPage--;
    }
  }

  // Main table pagination functions
  function goToMainTablePage(page: number) {
    if (page >= 1 && page <= mainTableTotalPages) {
      mainTableCurrentPage = page;
    }
  }

  function nextMainTablePage() {
    if (mainTableCurrentPage < mainTableTotalPages) {
      mainTableCurrentPage++;
    }
  }

  function prevMainTablePage() {
    if (mainTableCurrentPage > 1) {
      mainTableCurrentPage--;
    }
  }
</script>

<section>
  <h2 class="text-2xl font-bold flex items-center gap-2 text-gray-700">
    <Users class="w-5 h-5" /> Students
  </h2>
  <p class="mt-1 text-gray-500">Manage your students here.</p>
</section>
<hr class="my-4 border-gray-200" />

<main>
  <div
    class="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6 gap-3 font-sans"
  >
    <div class="flex flex-col sm:flex-row gap-2 w-full sm:w-auto">
      <Input
        type="text"
        placeholder="Search students..."
        class="w-full sm:w-60 border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
        bind:value={search}
      />

      <select
        class="w-full sm:w-auto border text-gray-500 text-sm border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
        bind:value={selectedYearId}
      >
        <option value="">All School Year</option>
        {#each schoolYears as sy}
          <option value={sy.school_year_id}>{sy.school_year}</option>
        {/each}
      </select>

      <select
        class="w-full sm:w-auto border text-gray-500 text-sm border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
        bind:value={selectedClassId}
      >
        <option value="">All Class</option>
        {#each classes as cls}
          <option value={cls.class_id}>{cls.class_name} - {cls.section}</option>
        {/each}
      </select>
    </div>

    <div class="flex flex-col sm:flex-row sm:justify-end sm:items-center gap-2 w-full">
      <Button class="flex items-center justify-center gap-2 bg-green-100 text-green-600 rounded-lg border border-green-500 shadow-md px-4 py-3 hover:bg-green-200 w-full sm:w-auto" onclick={openAddStudentModal}>
        <UserPlus />Add Student
      </Button>
    
      <label class="flex items-center justify-center gap-2 bg-green-600 text-white rounded-lg shadow-md px-4 py-3 hover:shadow-lg transition-shadow duration-200 hover:bg-green-700 cursor-pointer w-full sm:w-auto">
        <FileSpreadsheet />Import Students
        <Input type="file" accept=".xlsx,.xls,.csv" onchange={handleFileChange} class="hidden" />
      </label>
    </div>
    
  </div>


  <div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
    <div class="overflow-x-auto">
      <Table class="w-full">
        <TableHead class="bg-gray-100">
            <TableHeadCell class="px-2 sm:px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              <button class="flex items-center gap-1" onclick={() => toggleSort('student_code')}>
                STUDENT ID <span class="text-gray-400">{getSortIcon('student_code')}</span>
              </button>
            </TableHeadCell>
            <TableHeadCell class="px-2 sm:px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              <button class="flex items-center gap-1" onclick={() => toggleSort('student_name')}>
                NAME <span class="text-gray-400">{getSortIcon('student_name')}</span>
              </button>
            </TableHeadCell>
            <TableHeadCell class="px-2 sm:px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              <button class="flex items-center gap-1" onclick={() => toggleSort('class_name')}>
                CLASS <span class="text-gray-400">{getSortIcon('class_name')}</span>
              </button>
            </TableHeadCell>
            <TableHeadCell class="px-2 sm:px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              <button class="flex items-center gap-1" onclick={() => toggleSort('section')}>
                SECTION <span class="text-gray-400">{getSortIcon('section')}</span>
              </button>
            </TableHeadCell>
            <TableHeadCell class="px-2 sm:px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              <button class="flex items-center gap-1" onclick={() => toggleSort('school_year')}>
                SCHOOL YEAR <span class="text-gray-400">{getSortIcon('school_year')}</span>
              </button>
            </TableHeadCell>
            <TableHeadCell class="px-2 sm:px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</TableHeadCell>
          </TableHead>
        <TableBody class="bg-white divide-y divide-gray-200">
          {#if loading}
            {#each Array(5) as _, i}
              <TableBodyRow class="hover:bg-gray-50">
                <TableBodyCell class="px-6 py-4">
                  <div class="h-4 bg-gray-200 rounded animate-pulse w-16"></div>
                </TableBodyCell>
                <TableBodyCell class="px-6 py-4">
                  <div class="h-4 bg-gray-200 rounded animate-pulse w-32"></div>
                </TableBodyCell>
                <TableBodyCell class="px-6 py-4">
                  <div class="h-4 bg-gray-200 rounded animate-pulse w-24"></div>
                </TableBodyCell>
                <TableBodyCell class="px-6 py-4">
                  <div class="h-4 bg-gray-200 rounded animate-pulse w-20"></div>
                </TableBodyCell>
                <TableBodyCell class="px-6 py-4">
                  <div class="h-4 bg-gray-200 rounded animate-pulse w-28"></div>
                </TableBodyCell>
                <TableBodyCell class="px-6 py-4">
                  <div class="flex gap-2">
                    <div class="h-8 bg-gray-200 rounded animate-pulse w-12"></div>
                    <div class="h-8 bg-gray-200 rounded animate-pulse w-16"></div>
                  </div>
                </TableBodyCell>
              </TableBodyRow>
            {/each}
          {:else if filteredStudents.length === 0 && !loading}
          <TableBodyRow>
            <TableBodyCell colspan=6 class="p-0">
              <div class="flex flex-col items-center justify-center min-h-[120px] text-gray-500">
                <Frown class="w-8 h-8 mb-2 text-gray-400" />
                <span>No students found</span>
              </div>
            </TableBodyCell>
          </TableBodyRow>                
          {:else}
            {#each paginatedStudents as student, index}
              <TableBodyRow class="hover:bg-gray-50">
                <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2 text-xs font-medium text-gray-700 border-r border-gray-200">
                  {student.student_code}
                </TableBodyCell>
                <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2 text-xs text-gray-900">
                  {student.student_name}
                </TableBodyCell>
                <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2 text-xs text-gray-500">
                  {student.class?.class_name || "N/A"}
                </TableBodyCell>
                <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2 text-xs text-gray-500">
                  {student.class?.section || "N/A"}
                </TableBodyCell>
                <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2 text-xs text-gray-500">
                  {student.class?.schoolyear?.school_year || "N/A"}
                </TableBodyCell>
                <TableBodyCell class="px-2 sm:px-3 py-1.5 sm:py-2 text-xs">
                  <div class="flex items-center gap-2">
                    <button class="text-blue-600 hover:text-blue-900 text-xs px-2 py-1" onclick={() => openEditStudentModal(student)}>
                      Edit
                    </button>
                    <button class="text-red-600 hover:text-red-900 text-xs px-2 py-1" onclick={() => openDeleteStudentModal(student)}>
                      Delete
                    </button>
                  </div>
                </TableBodyCell>
              </TableBodyRow>
            {/each}
          {/if}
        </TableBody>
      </Table>
    </div>
  </div>

  <!-- Main Table Pagination -->
  {#if filteredStudents.length > 0 && mainTableTotalPages > 1}
    <div class="mt-6 bg-white rounded-lg border border-gray-200 p-4">
      <div class="flex flex-col sm:flex-row items-center justify-between gap-4">
        <!-- Items per page selector -->
        <div class="flex items-center gap-2 text-sm text-gray-600">
          <span>Items per page:</span>
          <select
            class="border border-gray-300 rounded px-2 py-1 text-sm"
            bind:value={mainTableItemsPerPage}
          >
            <option value={5}>5</option>
            <option value={10}>10</option>
            <option value={20}>20</option>
            <option value={50}>50</option>
            <option value={100}>100</option>
          </select>
        </div>

        <!-- Pagination info -->
        <div class="text-sm text-gray-700">
          Showing {mainTableStartIndex + 1} to {Math.min(mainTableEndIndex, filteredStudents.length)} of {filteredStudents.length} entries
        </div>

        <!-- Pagination controls -->
        <div class="flex items-center gap-2">
          <button
            onclick={prevMainTablePage}
            disabled={mainTableCurrentPage === 1}
            class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Previous
          </button>
          
          <div class="flex items-center gap-1">
            {#each Array.from({ length: Math.min(5, mainTableTotalPages) }, (_, i) => {
              const startPage = Math.max(1, mainTableCurrentPage - 2);
              const pageNum = startPage + i;
              if (pageNum > mainTableTotalPages) return null;
              return pageNum;
            }) as pageNum}
              {#if pageNum}
                <button
                  onclick={() => goToMainTablePage(pageNum)}
                  class="px-3 py-1 text-sm border rounded {mainTableCurrentPage === pageNum ? 'bg-green-600 text-white border-green-600' : 'border-gray-300 hover:bg-gray-100'}"
                >
                  {pageNum}
                </button>
              {/if}
            {/each}
          </div>
          
          <button
            onclick={nextMainTablePage}
            disabled={mainTableCurrentPage === mainTableTotalPages}
            class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Next
          </button>
        </div>
      </div>
    </div>
  {/if}
</main>

{#if uploadingFile}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
    <div class="bg-white rounded-lg shadow-lg p-6 flex items-center gap-3">
      <Loader class="w-5 h-5 animate-spin text-green-600" />
      <span class="text-sm text-gray-700">Uploading your file...</span>
    </div>
  </div>
{/if}

{#if showStudentModal}
  <div
    class="fixed inset-0 bg-black/40 flex items-center justify-center z-50 px-4 font-sans"
  >
    <div class="bg-white rounded-lg shadow-lg w-full max-w-md p-4 sm:p-6 relative">
      <button
        onclick={() => (showStudentModal = false)}
        class="absolute top-3 right-3 text-gray-500 hover:text-gray-700"
      >
        <X class="w-5 h-5" />
      </button>

      <Label class="text-lg font-semibold mb-4 text-center sm:text-left">
        {editingStudent ? "Edit Student" : "Add Student"}
      </Label>

      <div class="space-y-3">
        <Input
          type="text"
          placeholder="Student Code"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
          bind:value={newStudent.student_code}
        />
        <Input
          type="text"
          placeholder="Student Name"
          class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
          bind:value={newStudent.student_name}
        />

        <select
          class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500 font-sans text-gray-500"
          bind:value={newStudent.class_id}
        >
          <option value="">Select Class</option>
          {#each classes as cls}
            <option value={cls.class_id}>{cls.class_name} - {cls.class_code} ({cls.section})</option>
          {/each}
        </select>
      </div>

      <div class="mt-5 flex flex-col sm:flex-row justify-end gap-2">
        <Button
          onclick={() => (showStudentModal = false)}
          class="w-full sm:w-auto px-4 py-2 border border-gray-300 rounded-lg text-gray-600 hover:bg-gray-100"
          >Cancel</Button
        >
        <Button
          onclick={saveStudent}
          class="w-full sm:w-auto px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          disabled={savingStudent}
        >
          {#if savingStudent}
            <Loader class="w-4 h-4 animate-spin" />
          {/if}
          {editingStudent ? "Update" : "Add"}
        </Button>
      </div>
    </div>
  </div>
{/if}

{#if deleteModal && studentToDelete}
  <div class="fixed inset-0 flex items-center justify-center bg-black/50 z-50">
    <div class="bg-white rounded-lg shadow-lg w-full max-w-sm sm:max-w-md p-6 text-center relative">
     <Siren class="mx-auto mb-4 h-12 w-12 text-red-400" />
      <Label class="mb-5 text-lg font-semibold text-gray-700">
        Are you sure you want to delete <br>"{studentToDelete.student_name}"?
      </Label>
      <p class="text-sm text-gray-500 mb-5">This action cannot be undone.</p>
      <div class="mt-5 flex flex-col sm:flex-row justify-center gap-3">
        <Button
          onclick={() => (deleteModal = false)}
          class="w-full sm:w-auto px-4 py-2 border border-gray-300 rounded-lg text-gray-600 hover:bg-gray-100"
          disabled={savingStudent}>Cancel</Button
        >
        <Button
          onclick={confirmDeleteStudent}
          class="w-full sm:w-auto px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          disabled={savingStudent}
        >
          {#if savingStudent}
            <Loader class="w-4 h-4 animate-spin" />
          {/if}
          Yes, Delete
        </Button>
      </div>
    </div>
  </div>
{/if}

{#if showToast}
  <div class="fixed top-4 right-4 z-50">
    <Toast
      class="bg-white border border-gray-200 rounded-lg shadow-lg p-4 flex items-center gap-3 min-w-80"
      transition={fly} params={{ x: 200 }}
    >
      {#snippet icon()}
      <div class="flex-shrink-0">
        {#if toastType === "success"}
          <div class="w-5 h-5 bg-green-100 rounded-full flex items-center justify-center">
            <BadgeCheckIcon class="w-6 h-6 text-green-600" />
          </div>
        {:else}
          <div class="w-5 h-5 bg-red-100 rounded-full flex items-center justify-center">
            <svg class="w-3 h-3 text-red-600" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
            </svg>
          </div>
        {/if}
      </div>
      {/snippet}
      <div class="flex-1">
        <p class="text-sm font-medium text-gray-900">{toastMessage}</p>
      </div>
    </Toast>
  </div>
{/if}

<!-- Import Preview Modal -->
{#if showImportModal}
  <div class="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
    <div class="bg-white rounded-lg shadow-xl max-w-6xl w-full max-h-[90vh] flex flex-col">
      <!-- Modal Header -->
      <div class="flex items-center justify-between p-6 border-b border-gray-200">
        <h3 class="text-xl font-semibold text-gray-900">Import Students Preview</h3>
        <button
          onclick={closeImportModal}
          class="text-gray-400 hover:text-gray-600 transition-colors"
          aria-label="Close modal"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>

      <!-- Modal Body -->
      <div class="flex-1 overflow-hidden flex flex-col">
        <!-- Controls -->
        <div class="p-6 border-b border-gray-200 bg-gray-50">
          <div class="flex flex-col lg:flex-row gap-4 items-start lg:items-center justify-between">
            <div class="flex flex-col sm:flex-row gap-3 w-full lg:w-auto">
              <select
                class="w-full sm:w-auto border text-gray-500 text-sm border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-green-500"
                bind:value={importClassId}
              >
                <option value="">Select Class for Import</option>
                {#each classes as cls}
                  <option value={cls.class_id}>{cls.class_name} - {cls.section}</option>
                {/each}
              </select>
              
              <div class="flex items-center gap-2 text-sm text-gray-600">
                <span>Items per page:</span>
                <select
                  class="border border-gray-300 rounded px-2 py-1 text-sm"
                  bind:value={itemsPerPage}
                >
                  <option value={5}>5</option>
                  <option value={10}>10</option>
                  <option value={20}>20</option>
                  <option value={50}>50</option>
                </select>
              </div>
            </div>
            
            <div class="flex gap-2">
              <button
                onclick={importStudents}
                disabled={importing || !importClassId}
                class="bg-green-600 hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed text-white px-4 py-2 rounded-lg text-sm font-medium flex items-center gap-2"
              >
                {#if importing}
                  <Loader class="w-4 h-4 animate-spin" />
                  Importing...
                {:else}
                  <ClipboardList class="w-4 h-4" />
                  Import Students
                {/if}
              </button>
              
              <button
                onclick={clearImportData}
                disabled={importing}
                class="bg-gray-500 hover:bg-gray-600 disabled:bg-gray-400 disabled:cursor-not-allowed text-white px-4 py-2 rounded-lg text-sm font-medium"
              >
                Cancel
              </button>
            </div>
          </div>
          
          <div class="mt-4 bg-yellow-50 border border-yellow-200 rounded-lg p-3">
            <p class="text-sm text-yellow-800">
              <strong>Note:</strong> Please select a class for the imported students before clicking "Import Students". 
              All {filteredData.length} students will be assigned to the selected class.
            </p>
          </div>
        </div>

        <!-- Table Container -->
        <div class="flex-1 overflow-auto">
          <div class="p-6">
            <div class="overflow-x-auto">
              <Table class="w-full">
                <TableHead class="bg-gray-100">
                  <TableHeadCell class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">No</TableHeadCell>
                  <TableHeadCell class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Code</TableHeadCell>
                  <TableHeadCell class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</TableHeadCell>
                </TableHead>
                <TableBody class="bg-white divide-y divide-gray-200">
                  {#if importing}
                    {#each Array(3) as _, i}
                      <TableBodyRow class="hover:bg-gray-50">
                        <TableBodyCell class="px-4 py-3">
                          <div class="h-4 bg-gray-200 rounded animate-pulse w-8"></div>
                        </TableBodyCell>
                        <TableBodyCell class="px-4 py-3">
                          <div class="h-4 bg-gray-200 rounded animate-pulse w-16"></div>
                        </TableBodyCell>
                        <TableBodyCell class="px-4 py-3">
                          <div class="h-4 bg-gray-200 rounded animate-pulse w-32"></div>
                        </TableBodyCell>
                      </TableBodyRow>
                    {/each}
                  {:else if paginatedData.length === 0}
                    <TableBodyRow>
                      <TableBodyCell colspan={3} class="px-4 py-8 text-center text-gray-500">
                        No data to display
                      </TableBodyCell>
                    </TableBodyRow>
                  {:else}
                    {#each paginatedData as row}
                      <TableBodyRow class="hover:bg-gray-50">
                        <TableBodyCell class="px-4 py-3 text-sm font-medium text-gray-900">
                          {row.No}
                        </TableBodyCell>
                        <TableBodyCell class="px-4 py-3 text-sm text-gray-500">
                          {row.Code}
                        </TableBodyCell>
                        <TableBodyCell class="px-4 py-3 text-sm text-gray-500">
                          {row.Name}
                        </TableBodyCell>
                      </TableBodyRow>
                    {/each}
                  {/if}
                </TableBody>
              </Table>
            </div>
          </div>
        </div>

        <!-- Pagination -->
        {#if totalPages > 1}
          <div class="border-t border-gray-200 p-4 bg-gray-50">
            <div class="flex items-center justify-between">
              <div class="text-sm text-gray-700">
                Showing {startIndex + 1} to {Math.min(endIndex, filteredData.length)} of {filteredData.length} entries
              </div>
              
              <div class="flex items-center gap-2">
                <button
                  onclick={prevPage}
                  disabled={currentPage === 1}
                  class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Previous
                </button>
                
                <div class="flex items-center gap-1">
                  {#each Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                    const startPage = Math.max(1, currentPage - 2);
                    const pageNum = startPage + i;
                    if (pageNum > totalPages) return null;
                    return pageNum;
                  }) as pageNum}
                    {#if pageNum}
                      <button
                        onclick={() => goToPage(pageNum)}
                        class="px-3 py-1 text-sm border rounded {currentPage === pageNum ? 'bg-green-600 text-white border-green-600' : 'border-gray-300 hover:bg-gray-100'}"
                      >
                        {pageNum}
                      </button>
                    {/if}
                  {/each}
                </div>
                
                <button
                  onclick={nextPage}
                  disabled={currentPage === totalPages}
                  class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Next
                </button>
              </div>
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}
