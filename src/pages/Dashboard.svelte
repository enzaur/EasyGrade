<script lang="ts">
  import { onMount } from 'svelte';
  import { LayoutDashboard, Users, BookOpen, GraduationCap, TrendingUp, Calendar, Award, AlertCircle } from 'lucide-svelte';
  import { supabase } from '../lib/supabase';

  interface DashboardStats {
    totalClasses: number;
    totalStudents: number;
    activeSchoolYears: number;
    averageClassSize: number;
  }

  interface RecentClass {
    class_id: number;
    class_name: string;
    class_code: string;
    section: string;
    students_count: number;
    school_year?: string;
  }

  // No extra interfaces needed after removing top performers

  let stats: DashboardStats = {
    totalClasses: 0,
    totalStudents: 0,
    activeSchoolYears: 0,
    averageClassSize: 0
  };

  let recentClasses: RecentClass[] = [];
  let loading = true;

  async function fetchDashboardData() {
    loading = true;
    
    try {
      // Fetch classes with student counts
      const { data: classesData } = await supabase
        .from('class')
        .select(`
          class_id,
          class_name,
          class_code,
          section,
          school_year,
          schoolyear:school_year(school_year_id, school_year),
          students:student(count)
        `)
        .eq('is_archived', false)
        .order('class_id', { ascending: false })
        .limit(5);

      // Fetch total students (count all students)
      const { count: studentCount } = await supabase
        .from('student')
        .select('*', { count: 'exact', head: true });

      // Fetch active school years
      const { data: schoolYearsData } = await supabase
        .from('schoolyear')
        .select('school_year_id');

      // Process classes data
      const classes = (classesData || []).map((c: any) => ({
        class_id: c.class_id,
        class_name: c.class_name,
        class_code: c.class_code,
        section: c.section,
        students_count: Array.isArray(c.students) && c.students.length > 0 && typeof c.students[0].count === 'number'
          ? c.students[0].count
          : 0,
        school_year: c.schoolyear?.school_year || 'Unknown'
      }));

      recentClasses = classes;

      // Calculate stats
      const totalStudentsInClasses = classes.reduce((sum, c) => sum + c.students_count, 0);
      stats = {
        totalClasses: classes.length,
        totalStudents: studentCount || 0,
        activeSchoolYears: schoolYearsData?.length || 0,
        averageClassSize: classes.length > 0 ? Math.round(totalStudentsInClasses / classes.length) : 0
      };

      // Simplified fetchDashboardData - only fetch classes

    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    } finally {
      loading = false;
    }
  }

  // Removed filtering functions as they're no longer needed

  onMount(() => {
    fetchDashboardData();
  });
</script>

<section>
  <h2 class="text-2xl font-bold flex items-center gap-2 text-gray-700">
    <LayoutDashboard class="w-5 h-5" /> Dashboard
  </h2>
  <p class="mt-2 text-gray-500">Welcome to your grade tracking system.</p>
</section>
<hr class="my-4 border-gray-200" />

{#if loading}
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
    {#each Array(4) as _}
      <div class="bg-white rounded-lg shadow-md p-6 border border-gray-200">
        <div class="h-4 bg-gray-200 rounded animate-pulse w-24 mb-4"></div>
        <div class="h-8 bg-gray-200 rounded animate-pulse w-16"></div>
      </div>
    {/each}
  </div>
{:else}
  <!-- Statistics Cards -->
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
    <!-- Total Classes -->
    <div class="bg-gradient-to-br from-blue-500 to-blue-600 rounded-lg shadow-md p-6 text-white transform hover:scale-105 transition-transform duration-200">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-blue-100 text-sm font-medium uppercase tracking-wide">Total Classes</p>
          <p class="text-3xl font-bold mt-2">{stats.totalClasses}</p>
        </div>
        <BookOpen class="w-12 h-12 text-blue-200 opacity-80" />
      </div>
    </div>

    <!-- Total Students -->
    <div class="bg-gradient-to-br from-green-500 to-green-600 rounded-lg shadow-md p-6 text-white transform hover:scale-105 transition-transform duration-200">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-green-100 text-sm font-medium uppercase tracking-wide">Total Students</p>
          <p class="text-3xl font-bold mt-2">{stats.totalStudents}</p>
        </div>
        <Users class="w-12 h-12 text-green-200 opacity-80" />
      </div>
    </div>

    <!-- School Years -->
    <div class="bg-gradient-to-br from-purple-500 to-purple-600 rounded-lg shadow-md p-6 text-white transform hover:scale-105 transition-transform duration-200">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-purple-100 text-sm font-medium uppercase tracking-wide">School Years</p>
          <p class="text-3xl font-bold mt-2">{stats.activeSchoolYears}</p>
        </div>
        <Calendar class="w-12 h-12 text-purple-200 opacity-80" />
      </div>
    </div>

    <!-- Average Class Size -->
    <div class="bg-gradient-to-br from-orange-500 to-orange-600 rounded-lg shadow-md p-6 text-white transform hover:scale-105 transition-transform duration-200">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-orange-100 text-sm font-medium uppercase tracking-wide">Avg Class Size</p>
          <p class="text-3xl font-bold mt-2">{stats.averageClassSize}</p>
        </div>
        <TrendingUp class="w-12 h-12 text-orange-200 opacity-80" />
      </div>
    </div>
  </div>

  <!-- Main Content Grid -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <!-- Recent Classes -->
    <div class="bg-white rounded-lg shadow-md border border-gray-200 overflow-hidden">
      <div class="bg-gradient-to-r from-blue-50 to-blue-100 px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-800 flex items-center gap-2">
          <BookOpen class="w-5 h-5 text-blue-600" />
          Recent Classes
        </h3>
      </div>
      <div class="p-6">
        {#if recentClasses.length === 0}
          <div class="flex flex-col items-center justify-center py-8 text-gray-500">
            <AlertCircle class="w-12 h-12 mb-3 text-gray-400" />
            <p class="text-sm">No classes found</p>
          </div>
        {:else}
          <div class="space-y-4">
            {#each recentClasses as cls}
              <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors duration-150">
                <div class="flex-1">
                  <h4 class="font-semibold text-gray-800">{cls.class_name}</h4>
                  <p class="text-sm text-gray-500">{cls.class_code} - {cls.section}</p>
                  <p class="text-xs text-gray-400 mt-1">{cls.school_year}</p>
                </div>
                <div class="flex items-center gap-2 text-blue-600">
                  <Users class="w-4 h-4" />
                  <span class="font-semibold">{cls.students_count}</span>
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </div>

    <!-- Quick Actions -->
    <div class="bg-gradient-to-r from-indigo-50 to-purple-50 rounded-lg shadow-md border border-indigo-200">
      <div class="px-6 py-4 border-b border-indigo-200">
        <h3 class="text-lg font-semibold text-gray-800 flex items-center gap-2">
          <GraduationCap class="w-5 h-5 text-indigo-600" />
          Quick Actions
        </h3>
      </div>
      <div class="p-6">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <a href="#/classes" class="flex items-center gap-3 p-4 bg-white rounded-lg hover:shadow-lg transition-shadow duration-200 border border-gray-200">
            <BookOpen class="w-8 h-8 text-blue-600" />
            <span class="font-medium text-gray-700">Manage Classes</span>
          </a>
          <a href="#/students" class="flex items-center gap-3 p-4 bg-white rounded-lg hover:shadow-lg transition-shadow duration-200 border border-gray-200">
            <Users class="w-8 h-8 text-green-600" />
            <span class="font-medium text-gray-700">Manage Students</span>
          </a>
          <a href="#/gradebook" class="flex items-center gap-3 p-4 bg-white rounded-lg hover:shadow-lg transition-shadow duration-200 border border-gray-200">
            <Award class="w-8 h-8 text-purple-600" />
            <span class="font-medium text-gray-700">Grade Book</span>
          </a>
          <a href="#/settings" class="flex items-center gap-3 p-4 bg-white rounded-lg hover:shadow-lg transition-shadow duration-200 border border-gray-200">
            <Calendar class="w-8 h-8 text-orange-600" />
            <span class="font-medium text-gray-700">Settings</span>
          </a>
        </div>
      </div>
    </div>
  </div>
{/if}
