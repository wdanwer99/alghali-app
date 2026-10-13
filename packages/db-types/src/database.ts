// GENERATED FILE — do not edit by hand.
// Regenerate with `pnpm db:types`.

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      addresses: {
        Row: {
          created_at: string
          description_ar: string | null
          id: string
          is_default: boolean
          label: string
          lat: number
          lng: number
          location: unknown
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          description_ar?: string | null
          id?: string
          is_default?: boolean
          label: string
          lat: number
          lng: number
          location?: unknown
          updated_at?: string
          user_id?: string
        }
        Update: {
          created_at?: string
          description_ar?: string | null
          id?: string
          is_default?: boolean
          label?: string
          lat?: number
          lng?: number
          location?: unknown
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      app_settings: {
        Row: {
          description: string | null
          is_public: boolean
          key: string
          updated_at: string
          updated_by: string | null
          value: Json
        }
        Insert: {
          description?: string | null
          is_public?: boolean
          key: string
          updated_at?: string
          updated_by?: string | null
          value: Json
        }
        Update: {
          description?: string | null
          is_public?: boolean
          key?: string
          updated_at?: string
          updated_by?: string | null
          value?: Json
        }
        Relationships: []
      }
      audit_log: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          data: Json | null
          entity: string
          entity_id: string | null
          id: number
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          data?: Json | null
          entity: string
          entity_id?: string | null
          id?: never
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          data?: Json | null
          entity?: string
          entity_id?: string | null
          id?: never
        }
        Relationships: []
      }
      devices: {
        Row: {
          app: string
          app_build: number | null
          created_at: string
          fcm_token: string
          id: string
          last_seen_at: string
          locale: string | null
          platform: string
          user_id: string
        }
        Insert: {
          app: string
          app_build?: number | null
          created_at?: string
          fcm_token: string
          id?: string
          last_seen_at?: string
          locale?: string | null
          platform: string
          user_id: string
        }
        Update: {
          app?: string
          app_build?: number | null
          created_at?: string
          fcm_token?: string
          id?: string
          last_seen_at?: string
          locale?: string | null
          platform?: string
          user_id?: string
        }
        Relationships: []
      }
      garage_vehicles: {
        Row: {
          created_at: string
          id: string
          is_default: boolean
          nickname: string | null
          plate: string | null
          user_id: string
          variant_id: string
          vin: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          is_default?: boolean
          nickname?: string | null
          plate?: string | null
          user_id?: string
          variant_id: string
          vin?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          is_default?: boolean
          nickname?: string | null
          plate?: string | null
          user_id?: string
          variant_id?: string
          vin?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "garage_vehicles_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "vehicle_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      idempotency_keys: {
        Row: {
          created_at: string
          key: string
          op: string
          response: Json
          user_id: string
        }
        Insert: {
          created_at?: string
          key: string
          op: string
          response: Json
          user_id: string
        }
        Update: {
          created_at?: string
          key?: string
          op?: string
          response?: Json
          user_id?: string
        }
        Relationships: []
      }
      import_jobs: {
        Row: {
          created: number
          created_at: string
          created_by: string | null
          failed: number
          file_name: string | null
          id: string
          report: Json
          shop_id: string
          total: number
          updated: number
        }
        Insert: {
          created: number
          created_at?: string
          created_by?: string | null
          failed: number
          file_name?: string | null
          id?: string
          report: Json
          shop_id: string
          total: number
          updated: number
        }
        Update: {
          created?: number
          created_at?: string
          created_by?: string | null
          failed?: number
          file_name?: string | null
          id?: string
          report?: Json
          shop_id?: string
          total?: number
          updated?: number
        }
        Relationships: [
          {
            foreignKeyName: "import_jobs_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      job_types: {
        Row: {
          code: string
          id: string
          name_ar: string
          name_en: string
          sort: number
          updated_at: string
        }
        Insert: {
          code: string
          id?: string
          name_ar: string
          name_en: string
          sort?: number
          updated_at?: string
        }
        Update: {
          code?: string
          id?: string
          name_ar?: string
          name_en?: string
          sort?: number
          updated_at?: string
        }
        Relationships: []
      }
      listing_images: {
        Row: {
          base_key: string
          created_at: string
          id: string
          listing_id: string
          sort: number
        }
        Insert: {
          base_key: string
          created_at?: string
          id?: string
          listing_id: string
          sort?: number
        }
        Update: {
          base_key?: string
          created_at?: string
          id?: string
          listing_id?: string
          sort?: number
        }
        Relationships: [
          {
            foreignKeyName: "listing_images_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
        ]
      }
      listing_price_history: {
        Row: {
          changed_at: string
          changed_by: string | null
          id: number
          listing_id: string
          new_sdg: number | null
          old_sdg: number | null
        }
        Insert: {
          changed_at?: string
          changed_by?: string | null
          id?: never
          listing_id: string
          new_sdg?: number | null
          old_sdg?: number | null
        }
        Update: {
          changed_at?: string
          changed_by?: string | null
          id?: never
          listing_id?: string
          new_sdg?: number | null
          old_sdg?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "listing_price_history_listing_id_fkey"
            columns: ["listing_id"]
            isOneToOne: false
            referencedRelation: "listings"
            referencedColumns: ["id"]
          },
        ]
      }
      listings: {
        Row: {
          archived_at: string | null
          brand: string | null
          condition: Database["public"]["Enums"]["listing_condition"]
          created_at: string
          created_by: string | null
          id: string
          is_active: boolean
          note_ar: string | null
          part_id: string
          price_changed_at: string | null
          price_on_request: boolean
          price_sdg: number | null
          reserved_qty: number
          shop_id: string
          sku: string | null
          stock_qty: number
          updated_at: string
          version: number
          warranty_days: number
          was_sdg: number | null
        }
        Insert: {
          archived_at?: string | null
          brand?: string | null
          condition: Database["public"]["Enums"]["listing_condition"]
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          note_ar?: string | null
          part_id: string
          price_changed_at?: string | null
          price_on_request?: boolean
          price_sdg?: number | null
          reserved_qty?: number
          shop_id: string
          sku?: string | null
          stock_qty?: number
          updated_at?: string
          version?: number
          warranty_days?: number
          was_sdg?: number | null
        }
        Update: {
          archived_at?: string | null
          brand?: string | null
          condition?: Database["public"]["Enums"]["listing_condition"]
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          note_ar?: string | null
          part_id?: string
          price_changed_at?: string | null
          price_on_request?: boolean
          price_sdg?: number | null
          reserved_qty?: number
          shop_id?: string
          sku?: string | null
          stock_qty?: number
          updated_at?: string
          version?: number
          warranty_days?: number
          was_sdg?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "listings_part_id_fkey"
            columns: ["part_id"]
            isOneToOne: false
            referencedRelation: "parts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "listings_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      markets: {
        Row: {
          city_ar: string
          city_en: string
          id: string
          is_active: boolean
          name_ar: string
          name_en: string
          slug: string
          tz: string
          updated_at: string
        }
        Insert: {
          city_ar?: string
          city_en?: string
          id?: string
          is_active?: boolean
          name_ar: string
          name_en: string
          slug: string
          tz?: string
          updated_at?: string
        }
        Update: {
          city_ar?: string
          city_en?: string
          id?: string
          is_active?: boolean
          name_ar?: string
          name_en?: string
          slug?: string
          tz?: string
          updated_at?: string
        }
        Relationships: []
      }
      part_categories: {
        Row: {
          icon: string
          id: string
          is_active: boolean
          job_type_id: string | null
          name_ar: string
          name_en: string
          parent_id: string | null
          slug: string
          sort: number
          std_job_minutes: number | null
          updated_at: string
        }
        Insert: {
          icon?: string
          id?: string
          is_active?: boolean
          job_type_id?: string | null
          name_ar: string
          name_en: string
          parent_id?: string | null
          slug: string
          sort?: number
          std_job_minutes?: number | null
          updated_at?: string
        }
        Update: {
          icon?: string
          id?: string
          is_active?: boolean
          job_type_id?: string | null
          name_ar?: string
          name_en?: string
          parent_id?: string | null
          slug?: string
          sort?: number
          std_job_minutes?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "part_categories_job_type_id_fkey"
            columns: ["job_type_id"]
            isOneToOne: false
            referencedRelation: "job_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "part_categories_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "part_categories"
            referencedColumns: ["id"]
          },
        ]
      }
      part_fitments: {
        Row: {
          note_ar: string | null
          note_en: string | null
          part_id: string
          variant_id: string
        }
        Insert: {
          note_ar?: string | null
          note_en?: string | null
          part_id: string
          variant_id: string
        }
        Update: {
          note_ar?: string | null
          note_en?: string | null
          part_id?: string
          variant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "part_fitments_part_id_fkey"
            columns: ["part_id"]
            isOneToOne: false
            referencedRelation: "parts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "part_fitments_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "vehicle_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      part_search_docs: {
        Row: {
          doc: string
          part_id: string
          terms: string[]
          tsv: unknown
          updated_at: string
        }
        Insert: {
          doc: string
          part_id: string
          terms: string[]
          tsv: unknown
          updated_at?: string
        }
        Update: {
          doc?: string
          part_id?: string
          terms?: string[]
          tsv?: unknown
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "part_search_docs_part_id_fkey"
            columns: ["part_id"]
            isOneToOne: true
            referencedRelation: "parts"
            referencedColumns: ["id"]
          },
        ]
      }
      parts: {
        Row: {
          category_id: string
          created_at: string
          created_by_shop_id: string | null
          desc_ar: string | null
          desc_en: string | null
          id: string
          installable: boolean
          is_active: boolean
          is_verified: boolean
          keywords: string[]
          merged_into: string | null
          name_ar: string
          name_en: string
          oem_numbers: string[]
          std_job_minutes: number | null
          updated_at: string
        }
        Insert: {
          category_id: string
          created_at?: string
          created_by_shop_id?: string | null
          desc_ar?: string | null
          desc_en?: string | null
          id?: string
          installable?: boolean
          is_active?: boolean
          is_verified?: boolean
          keywords?: string[]
          merged_into?: string | null
          name_ar: string
          name_en?: string
          oem_numbers?: string[]
          std_job_minutes?: number | null
          updated_at?: string
        }
        Update: {
          category_id?: string
          created_at?: string
          created_by_shop_id?: string | null
          desc_ar?: string | null
          desc_en?: string | null
          id?: string
          installable?: boolean
          is_active?: boolean
          is_verified?: boolean
          keywords?: string[]
          merged_into?: string | null
          name_ar?: string
          name_en?: string
          oem_numbers?: string[]
          std_job_minutes?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "parts_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "part_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "parts_created_by_shop_fk"
            columns: ["created_by_shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "parts_merged_into_fkey"
            columns: ["merged_into"]
            isOneToOne: false
            referencedRelation: "parts"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          data_saver: boolean
          display_name: string
          email: string | null
          id: string
          locale: string
          phone: string | null
          phone_verified_at: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          data_saver?: boolean
          display_name?: string
          email?: string | null
          id: string
          locale?: string
          phone?: string | null
          phone_verified_at?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          data_saver?: boolean
          display_name?: string
          email?: string | null
          id?: string
          locale?: string
          phone?: string | null
          phone_verified_at?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      search_synonym_terms: {
        Row: {
          synonym_id: string
          term: string
        }
        Insert: {
          synonym_id: string
          term: string
        }
        Update: {
          synonym_id?: string
          term?: string
        }
        Relationships: [
          {
            foreignKeyName: "search_synonym_terms_synonym_id_fkey"
            columns: ["synonym_id"]
            isOneToOne: false
            referencedRelation: "search_synonyms"
            referencedColumns: ["id"]
          },
        ]
      }
      search_synonyms: {
        Row: {
          id: string
          terms: string[]
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          id?: string
          terms: string[]
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          id?: string
          terms?: string[]
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: []
      }
      shop_members: {
        Row: {
          added_by: string | null
          created_at: string
          role: string
          shop_id: string
          user_id: string
        }
        Insert: {
          added_by?: string | null
          created_at?: string
          role: string
          shop_id: string
          user_id: string
        }
        Update: {
          added_by?: string | null
          created_at?: string
          role?: string
          shop_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "shop_members_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      shop_specialities: {
        Row: {
          category_id: string | null
          make_id: string | null
          shop_id: string
        }
        Insert: {
          category_id?: string | null
          make_id?: string | null
          shop_id: string
        }
        Update: {
          category_id?: string | null
          make_id?: string | null
          shop_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "shop_specialities_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "part_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_specialities_make_id_fkey"
            columns: ["make_id"]
            isOneToOne: false
            referencedRelation: "vehicle_makes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shop_specialities_shop_id_fkey"
            columns: ["shop_id"]
            isOneToOne: false
            referencedRelation: "shops"
            referencedColumns: ["id"]
          },
        ]
      }
      shops: {
        Row: {
          about_ar: string | null
          about_en: string | null
          approved_at: string | null
          created_at: string
          created_by: string | null
          id: string
          landmark_ar: string | null
          landmark_en: string | null
          lat: number | null
          lng: number | null
          location: unknown
          name_ar: string
          name_en: string
          opening_hours: Json
          phone: string | null
          plot_no: string | null
          pos_m: number | null
          rating_avg: number
          rating_count: number
          side: string | null
          status: Database["public"]["Enums"]["partner_status"]
          status_reason: string | null
          storefront_key: string | null
          updated_at: string
          verified: boolean
          whatsapp: string | null
          zone_id: string
        }
        Insert: {
          about_ar?: string | null
          about_en?: string | null
          approved_at?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          landmark_ar?: string | null
          landmark_en?: string | null
          lat?: number | null
          lng?: number | null
          location?: unknown
          name_ar: string
          name_en?: string
          opening_hours?: Json
          phone?: string | null
          plot_no?: string | null
          pos_m?: number | null
          rating_avg?: number
          rating_count?: number
          side?: string | null
          status?: Database["public"]["Enums"]["partner_status"]
          status_reason?: string | null
          storefront_key?: string | null
          updated_at?: string
          verified?: boolean
          whatsapp?: string | null
          zone_id: string
        }
        Update: {
          about_ar?: string | null
          about_en?: string | null
          approved_at?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          landmark_ar?: string | null
          landmark_en?: string | null
          lat?: number | null
          lng?: number | null
          location?: unknown
          name_ar?: string
          name_en?: string
          opening_hours?: Json
          phone?: string | null
          plot_no?: string | null
          pos_m?: number | null
          rating_avg?: number
          rating_count?: number
          side?: string | null
          status?: Database["public"]["Enums"]["partner_status"]
          status_reason?: string | null
          storefront_key?: string | null
          updated_at?: string
          verified?: boolean
          whatsapp?: string | null
          zone_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "shops_zone_id_fkey"
            columns: ["zone_id"]
            isOneToOne: false
            referencedRelation: "zones"
            referencedColumns: ["id"]
          },
        ]
      }
      streets: {
        Row: {
          id: string
          is_active: boolean
          length_m: number
          market_id: string
          name_ar: string
          name_en: string
          origin: unknown
          origin_lat: number | null
          origin_lng: number | null
          slug: string
          updated_at: string
        }
        Insert: {
          id?: string
          is_active?: boolean
          length_m?: number
          market_id: string
          name_ar: string
          name_en: string
          origin?: unknown
          origin_lat?: number | null
          origin_lng?: number | null
          slug: string
          updated_at?: string
        }
        Update: {
          id?: string
          is_active?: boolean
          length_m?: number
          market_id?: string
          name_ar?: string
          name_en?: string
          origin?: unknown
          origin_lat?: number | null
          origin_lng?: number | null
          slug?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "streets_market_id_fkey"
            columns: ["market_id"]
            isOneToOne: false
            referencedRelation: "markets"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          granted_at: string
          granted_by: string | null
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          granted_at?: string
          granted_by?: string | null
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          granted_at?: string
          granted_by?: string | null
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      vehicle_makes: {
        Row: {
          id: string
          is_active: boolean
          name_ar: string
          name_en: string
          slug: string
          sort: number
          updated_at: string
        }
        Insert: {
          id?: string
          is_active?: boolean
          name_ar: string
          name_en: string
          slug: string
          sort?: number
          updated_at?: string
        }
        Update: {
          id?: string
          is_active?: boolean
          name_ar?: string
          name_en?: string
          slug?: string
          sort?: number
          updated_at?: string
        }
        Relationships: []
      }
      vehicle_models: {
        Row: {
          id: string
          is_active: boolean
          make_id: string
          name_ar: string
          name_en: string
          slug: string
          sort: number
          updated_at: string
        }
        Insert: {
          id?: string
          is_active?: boolean
          make_id: string
          name_ar: string
          name_en: string
          slug: string
          sort?: number
          updated_at?: string
        }
        Update: {
          id?: string
          is_active?: boolean
          make_id?: string
          name_ar?: string
          name_en?: string
          slug?: string
          sort?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "vehicle_models_make_id_fkey"
            columns: ["make_id"]
            isOneToOne: false
            referencedRelation: "vehicle_makes"
            referencedColumns: ["id"]
          },
        ]
      }
      vehicle_variants: {
        Row: {
          engine_ar: string
          engine_code: string | null
          engine_en: string
          fuel: string | null
          id: string
          is_active: boolean
          model_id: string
          slug: string
          sort: number
          updated_at: string
          year_from: number
          year_to: number
        }
        Insert: {
          engine_ar?: string
          engine_code?: string | null
          engine_en?: string
          fuel?: string | null
          id?: string
          is_active?: boolean
          model_id: string
          slug: string
          sort?: number
          updated_at?: string
          year_from: number
          year_to: number
        }
        Update: {
          engine_ar?: string
          engine_code?: string | null
          engine_en?: string
          fuel?: string | null
          id?: string
          is_active?: boolean
          model_id?: string
          slug?: string
          sort?: number
          updated_at?: string
          year_from?: number
          year_to?: number
        }
        Relationships: [
          {
            foreignKeyName: "vehicle_variants_model_id_fkey"
            columns: ["model_id"]
            isOneToOne: false
            referencedRelation: "vehicle_models"
            referencedColumns: ["id"]
          },
        ]
      }
      zones: {
        Row: {
          from_m: number
          id: string
          is_active: boolean
          name_ar: string
          name_en: string
          seq: number
          street_id: string
          to_m: number
          updated_at: string
        }
        Insert: {
          from_m: number
          id?: string
          is_active?: boolean
          name_ar: string
          name_en: string
          seq: number
          street_id: string
          to_m: number
          updated_at?: string
        }
        Update: {
          from_m?: number
          id?: string
          is_active?: boolean
          name_ar?: string
          name_en?: string
          seq?: number
          street_id?: string
          to_m?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "zones_street_id_fkey"
            columns: ["street_id"]
            isOneToOne: false
            referencedRelation: "streets"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      admin_grant_role: {
        Args: {
          p_role: Database["public"]["Enums"]["app_role"]
          p_user_id: string
        }
        Returns: undefined
      }
      admin_merge_parts: {
        Args: { p_from: string; p_into: string }
        Returns: undefined
      }
      admin_revoke_role: {
        Args: {
          p_role: Database["public"]["Enums"]["app_role"]
          p_user_id: string
        }
        Returns: undefined
      }
      admin_search_users: {
        Args: { p_limit?: number; p_q: string }
        Returns: {
          created_at: string
          display_name: string
          email: string
          id: string
          phone: string
          roles: Database["public"]["Enums"]["app_role"][]
        }[]
      }
      admin_set_shop_status: {
        Args: {
          p_reason?: string
          p_shop_id: string
          p_status: Database["public"]["Enums"]["partner_status"]
        }
        Returns: Json
      }
      admin_settings: {
        Args: never
        Returns: {
          description: string | null
          is_public: boolean
          key: string
          updated_at: string
          updated_by: string | null
          value: Json
        }[]
        SetofOptions: {
          from: "*"
          to: "app_settings"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      admin_update_setting: {
        Args: { p_key: string; p_value: Json }
        Returns: Json
      }
      admin_verify_shop: {
        Args: { p_shop_id: string; p_verified: boolean }
        Returns: Json
      }
      apply_as_shop: {
        Args: {
          p_about_ar?: string
          p_category_ids?: string[]
          p_idem?: string
          p_landmark_ar?: string
          p_lat?: number
          p_lng?: number
          p_make_ids?: string[]
          p_name_ar: string
          p_name_en?: string
          p_opening_hours?: Json
          p_phone: string
          p_plot_no?: string
          p_side?: string
          p_whatsapp?: string
          p_zone_id: string
        }
        Returns: Json
      }
      ar_normalize: { Args: { p: string }; Returns: string }
      ar_stem: { Args: { p_word: string }; Returns: string }
      audit: {
        Args: {
          p_action: string
          p_data?: Json
          p_entity: string
          p_entity_id: string
        }
        Returns: undefined
      }
      catalogue_snapshot: { Args: { p_since?: string }; Returns: Json }
      has_role: {
        Args: { p_role: Database["public"]["Enums"]["app_role"] }
        Returns: boolean
      }
      idem_begin: { Args: { p_idem: string; p_op: string }; Returns: Json }
      idem_finish: {
        Args: { p_idem: string; p_op: string; p_response: Json }
        Returns: Json
      }
      is_admin: { Args: never; Returns: boolean }
      is_open_at: { Args: { p_at: string; p_hours: Json }; Returns: boolean }
      is_shop_member: {
        Args: { p_owner_only?: boolean; p_shop_id: string }
        Returns: boolean
      }
      listing_json: { Args: { p_listing_id: string }; Returns: Json }
      me: { Args: never; Returns: Json }
      normalize_phone: { Args: { p: string }; Returns: string }
      part_detail: {
        Args: { p_part_id: string; p_variant_id?: string }
        Returns: Json
      }
      ping: { Args: never; Returns: Json }
      public_settings: { Args: never; Returns: Json }
      refresh_part_search_doc: {
        Args: { p_part_id: string }
        Returns: undefined
      }
      register_device: {
        Args: {
          p_app: string
          p_app_build?: number
          p_fcm_token: string
          p_locale?: string
          p_platform: string
        }
        Returns: Json
      }
      require_admin: { Args: never; Returns: string }
      require_shop: {
        Args: { p_owner_only?: boolean; p_shop_id: string }
        Returns: string
      }
      require_shop_writable: { Args: { p_shop_id: string }; Returns: string }
      require_user: { Args: never; Returns: string }
      search_expand: { Args: { p_term: string }; Returns: string[] }
      search_parts: {
        Args: {
          p_category_id?: string
          p_conditions?: Database["public"]["Enums"]["listing_condition"][]
          p_deals_only?: boolean
          p_in_stock_only?: boolean
          p_limit?: number
          p_offset?: number
          p_only_fits?: boolean
          p_price_max?: number
          p_q?: string
          p_shop_id?: string
          p_sort?: string
          p_variant_id?: string
        }
        Returns: {
          best_warranty_days: number
          category_id: string
          conditions: Database["public"]["Enums"]["listing_condition"][]
          fit: string
          from_sdg: number
          image_key: string
          installable: boolean
          is_verified: boolean
          listings: Json
          max_discount_percent: number
          name_ar: string
          name_en: string
          part_id: string
          rank: number
          shop_count: number
          std_job_minutes: number
          total_count: number
        }[]
      }
      search_query: { Args: { p_q: string }; Returns: unknown }
      search_terms: { Args: { p: string }; Returns: string[] }
      set_part_fitment_by_models: {
        Args: { p_model_ids: string[]; p_part_id: string }
        Returns: undefined
      }
      set_shop_specialities: {
        Args: {
          p_category_ids: string[]
          p_make_ids: string[]
          p_shop_id: string
        }
        Returns: undefined
      }
      shop_add_staff: {
        Args: { p_email: string; p_shop_id: string }
        Returns: Json
      }
      shop_archive_listing: {
        Args: { p_listing_id: string; p_shop_id: string }
        Returns: undefined
      }
      shop_bulk_update: {
        Args: { p_idem?: string; p_items: Json; p_shop_id: string }
        Returns: Json
      }
      shop_import_rows: {
        Args: {
          p_dry_run?: boolean
          p_file_name?: string
          p_idem?: string
          p_rows: Json
          p_shop_id: string
        }
        Returns: Json
      }
      shop_json: { Args: { p_shop_id: string }; Returns: Json }
      shop_listings: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_q?: string
          p_shop_id: string
        }
        Returns: Json[]
      }
      shop_remove_staff: {
        Args: { p_shop_id: string; p_user_id: string }
        Returns: undefined
      }
      shop_set_listing_images: {
        Args: { p_base_keys: string[]; p_listing_id: string; p_shop_id: string }
        Returns: Json
      }
      shop_staff: {
        Args: { p_shop_id: string }
        Returns: {
          added_at: string
          display_name: string
          email: string
          role: string
          user_id: string
        }[]
      }
      shop_update_profile: {
        Args: { p_patch: Json; p_shop_id: string }
        Returns: Json
      }
      shop_upsert_listing: {
        Args: {
          p_brand?: string
          p_condition: Database["public"]["Enums"]["listing_condition"]
          p_idem?: string
          p_is_active?: boolean
          p_listing_id?: string
          p_new_part?: Json
          p_note_ar?: string
          p_part_id?: string
          p_price_on_request?: boolean
          p_price_sdg?: number
          p_shop_id: string
          p_sku?: string
          p_stock_qty: number
          p_version?: number
          p_warranty_days?: number
        }
        Returns: Json
      }
      shop_write_part: {
        Args: { p: Json; p_part_id: string; p_shop_id: string }
        Returns: string
      }
      suggest_parts: {
        Args: {
          p_category_id?: string
          p_limit?: number
          p_q: string
          p_shop_id?: string
        }
        Returns: {
          category_id: string
          id: string
          is_verified: boolean
          model_count: number
          name_ar: string
          name_en: string
        }[]
      }
      try_uuid: { Args: { p: string }; Returns: string }
      unregister_device: { Args: { p_fcm_token: string }; Returns: undefined }
      update_profile: {
        Args: {
          p_data_saver?: boolean
          p_display_name?: string
          p_locale?: string
          p_phone?: string
        }
        Returns: Json
      }
      valid_opening_hours: { Args: { p: Json }; Returns: boolean }
      validate_setting: {
        Args: { p_key: string; p_value: Json }
        Returns: boolean
      }
    }
    Enums: {
      app_role: "BUYER" | "SHOP_OWNER" | "SHOP_STAFF" | "TECHNICIAN" | "ADMIN"
      listing_condition: "NEW_OEM" | "NEW_AFTERMARKET" | "USED"
      partner_status: "PENDING" | "APPROVED" | "REJECTED" | "SUSPENDED"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["BUYER", "SHOP_OWNER", "SHOP_STAFF", "TECHNICIAN", "ADMIN"],
      listing_condition: ["NEW_OEM", "NEW_AFTERMARKET", "USED"],
      partner_status: ["PENDING", "APPROVED", "REJECTED", "SUSPENDED"],
    },
  },
} as const
