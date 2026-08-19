import 'package:flutter/material.dart';

class BrowseCategory {
  final String id;
  final String title;
  final Color color;
  final String imageUrl;

  const BrowseCategory({
    required this.id,
    required this.title,
    required this.color,
    required this.imageUrl,
  });

  static List<BrowseCategory> get defaultCategories => const [
        BrowseCategory(
          id: 'tamil_hits',
          title: 'Tamil Hits',
          color: Color(0xFFE91429),
          imageUrl: 'https://res.cloudinary.com/dbsqhu7v5/image/upload/v1786269437/music/artwork/mersal-kailash_kher_d_sathyaprakash_deepak_pooja_av.jpg',
        ),
        BrowseCategory(
          id: 'pop',
          title: 'Pop & Dance',
          color: Color(0xFF148A08),
          imageUrl: 'https://res.cloudinary.com/dbsqhu7v5/image/upload/v1786268053/music/artwork/petta-anthony_dhaasan.jpg',
        ),
        BrowseCategory(
          id: 'hip_hop',
          title: 'Hip-Hop & Mass',
          color: Color(0xFFBC5900),
          imageUrl: 'https://res.cloudinary.com/dbsqhu7v5/image/upload/v1786269423/music/artwork/vedalam-anirudh_ravichander_badshah.jpg',
        ),
        BrowseCategory(
          id: 'romance',
          title: 'Romance & Love',
          color: Color(0xFFE8115B),
          imageUrl: 'https://res.cloudinary.com/dbsqhu7v5/image/upload/v1786267972/music/artwork/aadukalam-navin_iyer.jpg',
        ),
        BrowseCategory(
          id: 'chill',
          title: 'Chill & Relax',
          color: Color(0xFF477D95),
          imageUrl: 'https://res.cloudinary.com/dbsqhu7v5/image/upload/v1786268025/music/artwork/soorarai_pottru-g_v_prakash_kumar_christin_jos_govind_vasantha.jpg',
        ),
        BrowseCategory(
          id: 'kuthu',
          title: 'Kuthu Beats',
          color: Color(0xFF7D4B32),
          imageUrl: 'https://res.cloudinary.com/dbsqhu7v5/image/upload/v1786269398/music/artwork/kazhugu-krishnaraj_velmurugan_sathyan.jpg',
        ),
        BrowseCategory(
          id: 'party',
          title: 'Party & Club',
          color: Color(0xFF8D67AB),
          imageUrl: 'https://res.cloudinary.com/dbsqhu7v5/image/upload/v1786267901/music/artwork/170cm_indie-paal_dabba.jpg',
        ),
        BrowseCategory(
          id: 'melody',
          title: 'Melody King',
          color: Color(0xFFBA5D07),
          imageUrl: 'https://res.cloudinary.com/dbsqhu7v5/image/upload/v1786268062/music/artwork/samurai-harish_raghavendra_harini.jpg',
        ),
        BrowseCategory(
          id: 'classics',
          title: 'Tamil Classics',
          color: Color(0xFF503750),
          imageUrl: 'https://res.cloudinary.com/dbsqhu7v5/image/upload/v1786269402/music/artwork/thanga_meengal-sriram_parthasarathy.jpg',
        ),
        BrowseCategory(
          id: 'charts',
          title: 'Top 50 Tamil',
          color: Color(0xFF8C1932),
          imageUrl: 'https://res.cloudinary.com/dbsqhu7v5/image/upload/v1786269432/music/artwork/jagame_thandhiram-santhosh_narayanan_anthony_daasan.jpg',
        ),
      ];
}
